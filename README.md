# aws-alb-mtls-sample

AWS ALB の mTLS（Mutual TLS）認証を Terraform で構築する検証用リポジトリです。

## このリポジトリで行うこと

ALB の mTLS verify モードを最小構成で動かし、以下の3パターンを実際に試すことを目的とします。

| パターン | 内容 | 期待結果 |
| --- | --- | --- |
| 証明書あり | Trust Store に登録済み CA が署名した証明書を提示 | 200 OK |
| 証明書なし | クライアント証明書を提示しない | SSL エラー（HTTP 層に到達しない） |
| CA 不一致 | Trust Store に未登録の CA が署名した証明書を提示 | SSL エラー（同上） |

証明書検証の失敗は ALB アクセスログに記録されません。`ClientTLSNegotiationErrorCount` メトリクスと接続ログ（connection logs）で検知する流れも合わせて確認できます。

---

## 構成図

![docs/architecture.png](docs/architecture.png)

| コンポーネント | 説明 |
| --- | --- |
| クライアント | クライアント証明書を持つリクエスト元 |
| ACM | ALB HTTPS リスナー用サーバー証明書を管理 |
| ALB (mTLS verify) | クライアント証明書を Trust Store で検証し、合格したリクエストのみ転送 |
| ALB Trust Store | 信頼する CA 証明書のバンドルを保持（S3 から読み込み） |
| S3 Bucket | `ca-bundle.pem` の格納先（バージョニング・暗号化有効） |
| EC2 / Nginx | プライベートサブネット内のバックエンド。ALB SG からの HTTP:80 のみ許可 |
| IAM Role | EC2 に付与。SSM Session Manager でのアクセスを可能にする |

### 主なリソース

| リソース | 役割 |
| --- | --- |
| ALB | mTLS verify モードの HTTPS リスナーを持つロードバランサー |
| ALB Trust Store | 信頼する CA 証明書のバンドルを管理 |
| S3 Bucket | CA バンドル PEM ファイルの格納先（バージョニング有効） |
| EC2 (t3.micro) | Nginx を起動するバックエンドターゲット |
| IAM Role | EC2 が SSM Session Manager 経由で操作できるよう付与 |

---

## 前提条件

- [aws-vault](https://github.com/99designs/aws-vault) >= 7.x（認証情報の管理に使用）
- Terraform >= 1.10
- AWS CLI
- OpenSSL

---

## 使い方

### 0. aws-vault プロファイルを設定する

以降のコマンドはすべて `aws-vault exec` 経由で実行します。プロファイル名を変数に設定しておくと便利です。

```bash
export PROFILE=<your-aws-vault-profile>
```

### 1. 証明書の準備

```bash
mkdir key

# サーバー証明書（ACM にインポート）
openssl genrsa -out key/server.key 2048
openssl req -x509 -new -nodes -key key/server.key -sha256 -days 365 \
  -subj "/CN=mtls-sample.example.com" -out key/server.crt
aws-vault exec $PROFILE -- aws acm import-certificate \
  --certificate fileb://key/server.crt \
  --private-key fileb://key/server.key \
  --region ap-northeast-1

# Root CA とクライアント証明書（Trust Store に登録する CA）
openssl genrsa -out key/ca.key 2048
openssl req -x509 -new -nodes -key key/ca.key -sha256 -days 3650 \
  -subj "/CN=Test Root CA" -out key/ca.crt

openssl genrsa -out key/client.key 2048
openssl req -new -key key/client.key -subj "/CN=test-client" -out key/client.csr
openssl x509 -req -in key/client.csr -CA key/ca.crt -CAkey key/ca.key \
  -CAcreateserial -days 365 -sha256 -out key/client.crt

# CA 不一致テスト用：Trust Store に未登録の別 CA でクライアント証明書を発行
openssl genrsa -out key/other-ca.key 2048
openssl req -x509 -new -nodes -key key/other-ca.key -sha256 -days 3650 \
  -subj "/CN=Other Root CA" -out key/other-ca.crt

openssl genrsa -out key/other-ca-client.key 2048
openssl req -new -key key/other-ca-client.key -subj "/CN=other-client" -out key/other-ca-client.csr
openssl x509 -req -in key/other-ca-client.csr -CA key/other-ca.crt -CAkey key/other-ca.key \
  -CAcreateserial -days 365 -sha256 -out key/other-ca-client.crt
```

### 2. CA バンドルをローカルに配置

```bash
cp key/ca.crt key/ca-bundle.pem
```

### 3. Terraform

```bash
cd terraform

cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars に vpc_id / public_subnet_ids / private_subnet_id / certificate_arn を設定
# ca_bundle_local_path はデフォルト値 "../key/ca-bundle.pem" で動作します

aws-vault exec $PROFILE -- terraform init
aws-vault exec $PROFILE -- terraform plan
aws-vault exec $PROFILE -- terraform apply
```

`terraform apply` 時に S3 バケットの作成 → CA バンドルのアップロード → Trust Store の作成が自動的に順序どおり実行されます。

### 4. 動作確認

`terraform/` ディレクトリから以下を実行します。`terraform output` が AWS 認証を必要とするため、aws-vault セッション内で実行してください。

```bash
aws-vault exec $PROFILE -- bash -c '. ../scripts/operation-confirmation.sh'
```

スクリプトの内容は以下の通りです。

```bash
ALB_DNS=$(aws-vault exec $PROFILE -- terraform output -raw alb_dns_name)

# 証明書あり → 200 OK
curl -k --cert ../key/client.crt --key ../key/client.key https://$ALB_DNS/

# 証明書なし → SSL エラー
curl -k https://$ALB_DNS/

# CA 不一致 → SSL エラー
curl -k --cert ../key/other-ca-client.crt --key ../key/other-ca-client.key https://$ALB_DNS/
```

---

## Windows (Git Bash) での curl の注意点

Git for Windows に同梱されている `curl` は **Schannel**（Windows 標準の TLS ライブラリ）ビルドです。  
Schannel の `curl` は `--cert` オプションに PEM 形式（`.crt`）を渡すと以下のエラーになります。

```text
curl: (58) schannel: Failed to import cert file ..., last error is 0x80092002
```

### 対処方法

[scoop](https://scoop.sh/) で LibreSSL / OpenSSL ビルドの `curl` をインストールします。

```bash
scoop install curl
```

インストール後、Git Bash で新しいターミナルを開くか VSCode を再起動してください。  
`operation-confirmation.sh` は起動時に Schannel ビルドを自動検出し、scoop の `curl`（`~/scoop/shims/curl`）を優先するよう PATH を設定します。scoop の `curl` が見つからない場合はエラーメッセージを表示して終了します。

動作している curl を確認するには以下を実行します。

```bash
which curl
curl --version | grep -i ssl
# LibreSSL または OpenSSL と表示されれば OK
# Schannel と表示される場合は PATH が古い（ターミナルを再起動）
```

---

## 作成リソースの削除

```bash
aws-vault exec $PROFILE -- terraform destroy
```
