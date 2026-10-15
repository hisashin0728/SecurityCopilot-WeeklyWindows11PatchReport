# Weekly Windows 11 Patch Report

Microsoft Graph Windows Updates カタログの最新品質更新と、Microsoft Defender XDR
`DeviceInfo` の Windows 11 OS ビルドを週次で突合し、HTML メールを送信する
Security Copilot Standard Agent です。

## 分析内容

- Windows 11 feature version ごとの最新月例セキュリティ更新（KB、公開日、目標ビルド）
- Defender が直近 14 日に観測した適用済み、遅延、判定不能の端末数
- 判定可能端末を分母にした適用率と遅延率
- 4 週間の OS ビルド分布と適用トレンド
- feature version 別の適用状況
- パッチ適用遅延端末 Top 10
- 優先度付き推奨アクション

## 判定モデル

| 状態 | 判定 |
|---|---|
| 適用済み | Defender の完全な OS バージョンが同じ feature version の Graph 最新基準以上 |
| 遅延 | 同じ buildNumber で update build revision が最新基準未満 |
| 機能更新遅延 | サービス終了版、または最新基準に対応しない旧 feature version |
| 判定不能 | Graph 基準、feature version、または完全な端末バージョンが不足 |

`適用率 = 適用済み / 判定可能端末`、`遅延率 = 遅延端末 / 判定可能端末`
として算出します。判定不能端末は分母から除外し、別のデータ品質指標として表示します。

> Graph カタログの「配信済み」は Microsoft が更新を公開済みであることを示します。
> Intune / Windows Update for Business の割り当て成功やダウンロード成功を直接示すものでは
> ありません。「適用済み」は Defender が直近 14 日に観測した OS ビルドによる判定です。

## ファイル

| ファイル | 用途 |
|---|---|
| `WeeklyWindows11PatchReport.yaml` | **Security Copilot にアップロードするプラグイン マニフェスト**。Agent、KQL、Graph API、Logic App スキルを定義 |
| `WeeklyWindows11PatchReport_GraphAPI_openapi.yaml` | Graph beta API の OpenAPI 3.0 仕様。マニフェストから HTTPS で参照するファイルであり、Security Copilot へ直接アップロードしない |
| `WeeklyWindows11PatchReport_LogicApp_ARM.json` | Office 365 メール送信用 Logic App |
| `WeeklyWindows11PatchReport_SampleEmail.html` | 架空データによるレポート表示例 |
| `WeeklyWindows11PatchReport_card.html` | プラグイン カード |

> **重要:** Security Copilot の「カスタム プラグインの追加」で選択するファイルは
> `WeeklyWindows11PatchReport.yaml` です。
> `WeeklyWindows11PatchReport_GraphAPI_openapi.yaml` を直接選択すると、このファイルには
> Security Copilot の `Descriptor` がないため、
> `2002: Failed to load yaml: No SkillsetDescriptor is specified` が発生します。

## 前提条件

1. Security Copilot で Microsoft Defender XDR プラグインが有効
2. Defender for Endpoint に端末がオンボード済み
3. 専用EntraアプリにGraphアプリケーション権限 `WindowsUpdates.Read.All` を付与し、管理者同意済み
4. メール送信用 Logic App と Office 365 接続が利用可能
5. Security Copilot から GitHub raw の OpenAPI URL へ HTTPS アクセス可能

Microsoft Graph `/beta` API は変更される可能性があり、本番利用は Microsoft のサポート対象外です。
運用前と Graph API 変更時に OpenAPI 応答スキーマを再確認してください。

## デプロイ

### 1. Logic App

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fhisashin0728%2FSecurityCopilot-WeeklyWindows11PatchReport%2Frefs%2Fheads%2Fmain%2FWeeklyWindows11PatchReport_LogicApp_ARM.json)

上の **Deploy to Azure** ボタンを選択し、Azure ポータルで次を指定してデプロイします。

1. サブスクリプション
2. リソース グループ
3. リージョン
4. 送信先メールアドレス
5. Logic App 名（既定値: `PluginLogicApp_WeeklyWindows11PatchReport`）

デプロイ後、Azure ポータルで作成された Office 365 API 接続を開き、
送信に使用するアカウントで認証してください。ARM テンプレートのデプロイだけでは
Office 365 接続のサインインは完了しません。

ボタンが利用できない場合は、
[Azure ポータルでカスタム テンプレートを開く](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fhisashin0728%2FSecurityCopilot-WeeklyWindows11PatchReport%2Frefs%2Fheads%2Fmain%2FWeeklyWindows11PatchReport_LogicApp_ARM.json)
リンクを直接使用してください。

### 2. OpenAPI

マニフェストには、GitHub raw の公開済み OpenAPI URL が設定されています。

```yaml
OpenApiSpecUrl: https://raw.githubusercontent.com/hisashin0728/SecurityCopilot-WeeklyWindows11PatchReport/refs/heads/main/WeeklyWindows11PatchReport_GraphAPI_openapi.yaml
```

通常は書き換え不要です。リポジトリを fork して内容を変更する場合だけ、
fork 先の raw URL に変更してください。

OpenAPI ファイル単体は Security Copilot のプラグイン マニフェストではありません。
Security Copilot は `WeeklyWindows11PatchReport.yaml` の `OpenApiSpecUrl` を読み取り、
実行時にこの OpenAPI ファイルを HTTPS で取得します。

### 3. Security Copilot

1. `WeeklyWindows11PatchReport.yaml` の `<YOUR-TENANT-ID>` を実際のTenant IDへ置換
2. 編集した `WeeklyWindows11PatchReport.yaml` だけをカスタム プラグインとしてアップロード
3. エージェントの認証（代理認証）で実行用ユーザー アカウントを割り当て
4. Graph APIプラグインの認証に `OAuthClientCredentialsFlow` を設定
5. Logic App の Subscription ID、Resource Group、Workflow Name を設定
6. Agent を有効化

Agent は 604,800 秒（7 日）ごとに実行されます。

Security Copilot のカスタムエージェントはエージェントIDに対応していないため、
エージェント自体の実行には代理ユーザー認証を使用します。一方、Microsoft Graph
Windows Updates APIの呼び出しには、代理ユーザーとは別に専用Entraアプリの
OAuth 2.0クライアント資格情報フローを使用します。

マニフェストの認証設定:

```yaml
SupportedAuthTypes:
  - OAuthClientCredentialsFlow
Authorization:
  Type: OAuthClientCredentialsFlow
  TokenEndpoint: https://login.microsoftonline.com/<YOUR-TENANT-ID>/oauth2/v2.0/token
  Scopes: https://graph.microsoft.com/.default
  AuthorizationContentType: application/x-www-form-urlencoded
```

#### Graph用Entraアプリの作成

1. Microsoft Entra管理センターで「アプリの登録」→「新規登録」を選択
2. 名前を `SecurityCopilot-WeeklyWindows11PatchReport` などに設定
3. 「この組織ディレクトリのみに含まれるアカウント」を選択
4. リダイレクトURIは設定せず登録
5. 「APIのアクセス許可」→「Microsoft Graph」→「アプリケーションの許可」を選択
6. `WindowsUpdates.Read.All` を追加
7. テナントの管理者同意を付与
8. 「証明書とシークレット」でクライアントシークレットを作成し、値を安全に保管

#### Security Copilotのセットアップ画面で入力する値

`Resource` はこのプラグインでは常にMicrosoft Graphを指す固定値です。
ただし、現在のSecurity Copilotでは `OAuthClientCredentialsFlow` の認証セットアップ時に
`Resource` が必須入力欄として表示されます。これはプラグイン独自の設定パラメータではなく、
OAuth認証を初回構成するときに1回入力する値です。

Security Copilotの公開マニフェスト仕様では、`TokenEndpoint`、`Scopes`、
`ClientId`、`ClientSecret`、`AuthorizationContentType` は事前設定できますが、
`Resource` の事前設定フィールドは公開されていません。そのため、未サポートの
`Resource` プロパティをマニフェストへ追加せず、セットアップ画面で入力します。

セットアップ画面に表示される次の3項目を入力してください。

| 画面の項目 | 入力する値 |
|---|---|
| ClientId | 作成したEntraアプリのApplication (client) ID |
| ClientSecret | 作成したクライアントシークレットの**値** |
| Resource | `https://graph.microsoft.com` |

> **Resourceには `https://graph.microsoft.com` を入力します。**
> `/.default` や `/beta` は付けません。

入力例:

```text
ClientId:     00000000-0000-0000-0000-000000000000
ClientSecret: <Entraで作成したシークレットの値>
Resource:     https://graph.microsoft.com
```

Resourceに入力しない値:

```text
https://graph.microsoft.com/.default
https://graph.microsoft.com/beta
00000003-0000-0000-c000-000000000000
WindowsUpdates.Read.All
```

`Resource` はアクセストークンの対象APIを指定する欄です。Security Copilotは
この値を使用してMicrosoft Graph向けのトークンを取得します。
`WindowsUpdates.Read.All` はこの画面へ入力する値ではなく、Entraアプリの
Microsoft Graph **Application permission** として事前に付与します。

#### マニフェストに設定済みの値

次の値は `WeeklyWindows11PatchReport.yaml` に設定するため、セットアップ画面では
通常入力しません。

| マニフェスト項目 | 値 |
|---|---|
| TokenEndpoint | `https://login.microsoftonline.com/<TENANT-ID>/oauth2/v2.0/token` |
| Scopes | `https://graph.microsoft.com/.default` |
| AuthorizationContentType | `application/x-www-form-urlencoded` |

クライアントシークレットをマニフェストやGitHubへ記載しないでください。
有効期限を監視し、期限前にローテーションしてください。

代理ユーザー認証はカスタムエージェントの実行に引き続き必要で、画面に表示される
期限（現在は90日）までに再認証します。ただし、Graph APIの
`WindowsUpdates.Read.All` は代理ユーザーではなく、上記の専用Entraアプリへ付与します。

## トラブルシューティング

### `AADSTS65002: Consent between first party application ... must be configured via preauthorization`

Security CopilotのMicrosoft管理ファーストパーティ アプリから、Microsoft Graphの
`WindowsUpdates.Read.All` を代理認証で要求した場合に発生します。ファーストパーティ
アプリ間の権限はMicrosoft側の事前承認が必要で、テナント管理者の同意だけでは解消できません。

本リポジトリの最新マニフェストは、この制約を回避するため
`OAuthClientCredentialsFlow` を使用します。

1. 以前登録したプラグイン／エージェントを削除または更新
2. 最新の `WeeklyWindows11PatchReport.yaml` をダウンロードし、
   `<YOUR-TENANT-ID>` を実際のTenant IDへ置換して再アップロード
3. 専用EntraアプリのToken endpoint、Client ID、Client Secretを設定
4. エージェントの代理ユーザー認証も再設定
5. `ListWindowsQualityUpdates` を再実行

### `No SkillsetDescriptor is specified`

原因は、OpenAPI 仕様ファイルまたは ARM テンプレートを Security Copilot の
プラグイン マニフェストとしてアップロードしたことです。

1. エラー画面で戻る
2. 「カスタム プラグインの追加」を再実行
3. リポジトリの次のマニフェストをダウンロードし、
   [`WeeklyWindows11PatchReport.yaml`](https://raw.githubusercontent.com/hisashin0728/SecurityCopilot-WeeklyWindows11PatchReport/refs/heads/main/WeeklyWindows11PatchReport.yaml)
   の `<YOUR-TENANT-ID>` を実際のTenant IDへ置換
4. 編集した `WeeklyWindows11PatchReport.yaml` を選択
5. OpenAPI URL が自動的に読み込まれることを確認

アップロード対象ではないファイル:

- `WeeklyWindows11PatchReport_GraphAPI_openapi.yaml`
- `WeeklyWindows11PatchReport_LogicApp_ARM.json`
- `WeeklyWindows11PatchReport_SampleEmail.html`
- `WeeklyWindows11PatchReport_card.html`

## Defender KQL スキル

| スキル | 期間 | 出力 |
|---|---:|---|
| `GetWindows11PatchInventory` | 14 日 | OSVersionInfo / OSBuild / OSVersion 別台数 |
| `GetWindows11PatchTrend` | 28 日 | 週別 OS ビルド分布 |
| `GetWindows11PatchLagCandidates` | 14 日 | 古いビルド順の候補端末 50 台 |

クエリは `MergedToDeviceId` が空、`OnboardingStatus == Onboarded` の
Windows 11 最新レコードを対象にします。

## データ品質上の注意

- 14 日間 Defender に接続していない端末は母数に含まれません。
- `OSVersion` が `major.minor.build.revision` 形式でない端末は判定不能になり得ます。
- Insider、LTSC、hotpatch は標準の一般提供チャネルと分けて確認してください。
- Windows 11 のリリース情報ページは運用時の目視確認にも利用してください。

> この生成環境では Defender Advanced Hunting のテナント ライブ スキーマ取得ツールを
> 利用できなかったため、KQL は Microsoft Learn の最新 `DeviceInfo` スキーマを基準に
> 検証しています。導入先で初回実行前に各 KQL を Advanced Hunting でテストしてください。

## 公式資料

- [product resource type - Microsoft Graph beta](https://learn.microsoft.com/graph/api/resources/windowsupdates-product?view=graph-rest-beta)
- [List catalog entries - Microsoft Graph beta](https://learn.microsoft.com/graph/api/windowsupdates-catalog-list-entries?view=graph-rest-beta)
- [Windows 11 release information](https://learn.microsoft.com/windows/release-health/windows11-release-information)
- [DeviceInfo table](https://learn.microsoft.com/defender-xdr/advanced-hunting-deviceinfo-table)
