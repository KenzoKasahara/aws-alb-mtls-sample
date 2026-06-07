# Windows Git Bash では curl が Schannel ビルドの場合、PEM 証明書を --cert で渡せない。
# scoop でインストールした LibreSSL/OpenSSL ビルドの curl を優先する。
if curl --version 2>/dev/null | grep -qi schannel; then
  if [[ -x "$HOME/scoop/shims/curl" ]]; then
    export PATH="$HOME/scoop/shims:$PATH"
  else
    echo "Error: curl が Schannel ビルドです。'scoop install curl' を実行してください。" >&2
    echo "詳細は README の「Windows (Git Bash) での curl の注意点」を参照してください。" >&2
    exit 1
  fi
fi

ALB_DNS=$(terraform output -raw alb_dns_name)

# 証明書あり → 200 OK
curl -k --cert ../key/client.crt --key ../key/client.key https://$ALB_DNS/

# 証明書なし → SSL エラー
curl -k https://$ALB_DNS/

# CA 不一致 → SSL エラー
curl -k --cert ../key/other-ca-client.crt --key ../key/other-ca-client.key https://$ALB_DNS/
