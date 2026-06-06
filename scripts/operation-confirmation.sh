ALB_DNS=$(terraform output -raw alb_dns_name)

# 証明書あり → 200 OK
curl -k --cert ../key/client.crt --key ../key/client.key https://$ALB_DNS/

# 証明書なし → SSL エラー
curl -k https://$ALB_DNS/

# CA 不一致 → SSL エラー
curl -k --cert ../key/other-ca-client.crt --key ../key/other-ca-client.key https://$ALB_DNS/
