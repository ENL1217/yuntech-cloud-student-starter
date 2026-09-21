# W3 Sprint：巡檢服務雛型上線

W2 完成私有保存；本週讓同一個巡檢服務有可核對版本的健康頁。3–4 人一組，指定一位帳號持有人操作 AWS；其他人輪流規劃、審查、驗證與紀錄，不共用憑證。

## 本週提供與你要完成的部分

教師提供 [服務雛型](../../app/service.py)、[nginx 設定](../../deploy/nginx.conf)、[user data 打包器](../../deploy/make-user-data.sh)；你要核對網路、產生自己的部署計畫、用 AWS CLI 建立資源、診斷受控故障、回收並重建。提供的檔案不含 AWS 建立／刪除腳本、預填结果或帳號資源 ID。

範圍：同時僅一台 AL2023 x86_64 t3.micro、預設 VPC 的預設公有子網、加密 gp3 根磁碟且 DeleteOnTermination、IMDSv2 required；nginx:80 → 127.0.0.1:8080。標籤 `course=yuntech-115-1`、`week=w03`、`group=<本組名>`。
不做：HTTPS（W4）、事件 API、RDS、第二台同時運作的主機、NAT、EIP、負載平衡器、新 VPC、IAM 變更。

## 前置與方法

1. 完成 [環境步驟](../../docs/getting-started.md)，執行 `bash scripts/verify-aws.sh`；確認目前自己的 Lab 身分及 us-east-1。
2. 讀 [Agent 規則](../../AGENTS.md)。AWS 呼叫沿用 `scripts/lab.py` 的 `clean_env`／`run_aws`；不要用繼承環境切换帳號或 endpoint。
3. 記錄預設 VPC、預設子網與 AZ、其有效路由表的 IGW 預設路由、目前 AL2023 AMI 的名稱／x86_64／日期，以及 Codespace 對外 IPv4。沒有預設網路就停止求助，不自行新增。
4. 在 [資源清單範本](../../deploy/resources.example.md) 記錄每一輪精確 ID；所有入站規則只有 TCP 22、80，來源都是當次 Codespace IPv4 `/32`，不得 `0.0.0.0/0` 或 `::/0`。
5. SSH ed25519 私鑰只由工具在 Codespace 的 `~/.ssh` 生成並使用，權限 600；Agent 不讀取內容、不放 Git。只將對應公鑰匯入 EC2 key pair，連線核對主機指紋，不關閉主機金鑰驗證。
6. 程式變更必須先 commit，再打包：

   ```bash
   bash deploy/make-user-data.sh HEAD .local/w03-user-data.sh
   ```

   打包器只取指定 commit 的 `app/service.py` 與 `deploy/nginx.conf`，寫入完整 SHA；不取尚未提交的變更、不在 EC2 clone 私有 repo、不含 token。輸出原始 user data 小於 16 KiB；交給 AWS CLI 時理解其 base64 行為，避免重複編碼。

## T1–T4 任務卡與公開完成條件

| 卡 | 任務 | 完成條件與本組證據 |
|---|---|---|
| T1 | Agent 只提出部署計畫，另一位同學審查 | 精確網路／AMI／/32、資源型別、成本來源、回收清單；未核准前不建立 |
| T2 | 建立專用 SG、key pair、一台主機並部署雛型 | 記錄 running、status checks 2/2、cloud-init 完成、兩個 port 在聽、HTTP 200 的首次觀測時間；version 等於部署 commit；另記服務未就緒前一次 curl 的真實結果 |
| T3 | 先預測再做兩個故障，逐個恢復 | 移除且恢復完全相同的 80 入站規則；停止／啟動 inspection systemd 服務、保留 nginx。各填預測／實際／原因／恢復後結果，不預填成功 |
| T4 | 終止並確認回收，從同一 SHA 重建，再最終回收 | 兩轮 version 相同、重建耗時、instance terminated 且根 EBS／ENI／SG／key pair 已清除的讀回證據 |

Codespace 停止後再啟動，對外 IPv4 可能改變。恢復工作時先重新核對出口與 SG；若不同，列出精確舊／新 `/32` 取得核准後替換，不放寬來源。`cloud-init status --wait` 請記錄執行前後的 UTC 時間與退出結果；等待結束仍要另驗證 listener 與健康頁。

running 不代表 /health 已可用；觀測順序與實際完成順序可能不同。每個卡點最多診斷 10 分鐘，記錄最後成功層及錯誤再求助；最晚下課前 10 分鐘開始回收。

## 成功與故障契約

- `/health`：200，JSON 含 `status=ok`、`service=inspection`、`version=<40 字元 commit SHA>`、`started_at=<UTC>`。應用程式只聽 loopback，不開 8080 的 SG。
- SG 封鎖：對新的 HTTP 連線做有逾時限制的 curl；觀察 SSH 與 AWS CLI 是否仍可用。新連線與被追蹤的既有連線不同。
- nginx 活著、應用停止：觀察 HTTP 狀態與耗時；推論請求到達哪一層，再恢复服務。
- 教師延伸：停止 nginx 的拒絕連線對照；Stop／Start 的 IP 變化。SSM 僅在教師核准後，短暫掛既有 LabInstanceProfile 測試，不作為必修診斷通道、不修改 IAM。
- 來源限制包含瀏覽器：你 PC 的 IP 通常不是 Codespace IP。不要為了截圖放寬 SG；可經 Codespace 內受限的 HTTP 轉送並使用 private forwarded port，標註這是轉送檢視。

## Agent 與交付

提示起點：「讀本週任務卡，只列 T1 計畫、預測及需要我核准的精確資源，先不執行 AWS 變更。」每次工具核准先讀命令／差異；禁止永久自動核准。AccessDenied 停止該步；ExpiredToken 由帳號持有人更新憑證。

用 [報告範本](../../reports/TEMPLATE.md) 交增量報告：計畫與修正、五層時間、故障表、同版本重建、回收清單與讀回、一次自己的解釋。每人能說出來源→路由→SG→nginx→應用程式的請求旅程。不要提交密碼、私鑰、完整帳號或簽名網址；不要把未測寫成通過。停 Codespace 或 End Lab 都不能代替資源回收。

求助時附週次／卡片／commit／已去敏感的命令與錯誤／預期與實際／仍存在的資源 ID。計價依當期 [EC2 官方頁](https://aws.amazon.com/ec2/pricing/on-demand/)、[EBS](https://aws.amazon.com/ebs/pricing/) 與 [公有 IPv4](https://aws.amazon.com/vpc/pricing/)，不要把停止解讀為沒有費用。
