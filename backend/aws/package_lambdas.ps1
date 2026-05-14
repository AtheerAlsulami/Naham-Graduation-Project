param(
  [string]$OutputDir = "backend/aws/dist"
)

$ErrorActionPreference = "Stop"

$functions = @(
  @{
    FunctionName = "NahamAuthRegister"
    SourceFile   = "backend/aws/authRegister.js"
    Handler      = "authRegister.handler"
    ZipName      = "naham-auth-register.zip"
  },
  @{
    FunctionName = "NahamAuthLogin"
    SourceFile   = "backend/aws/authLogin.js"
    Handler      = "authLogin.handler"
    ZipName      = "naham-auth-login.zip"
  },
  @{
    FunctionName = "NahamAuthGoogleSignin"
    SourceFile   = "backend/aws/authGoogleSignin.js"
    Handler      = "authGoogleSignin.handler"
    ZipName      = "naham-auth-google-signin.zip"
  },
  @{
    FunctionName = "NahamUsersList"
    SourceFile   = "backend/aws/usersList.js"
    Handler      = "usersList.handler"
    ZipName      = "naham-users-list.zip"
  },
  @{
    FunctionName = "NahamUsersSave"
    SourceFile   = "backend/aws/usersSave.js"
    Handler      = "usersSave.handler"
    ZipName      = "naham-users-save.zip"
  },
  @{
    FunctionName = "NahamUsersDelete"
    SourceFile   = "backend/aws/usersDelete.js"
    Handler      = "usersDelete.handler"
    ZipName      = "naham-users-delete.zip"
  },
  @{
    FunctionName = "NahamUsersUpdateStatus"
    SourceFile   = "backend/aws/usersUpdateStatus.js"
    Handler      = "usersUpdateStatus.handler"
    ZipName      = "naham-users-update-status.zip"
  },
  @{
    FunctionName = "NahamUsersUploadUrl"
    SourceFile   = "backend/aws/usersUploadUrl.js"
    Handler      = "usersUploadUrl.handler"
    ZipName      = "naham-users-upload-url.zip"
  },
  @{
    FunctionName = "NahamFollows"
    SourceFile   = "backend/aws/follows.js"
    Handler      = "follows.handler"
    ZipName      = "naham-follows.zip"
  },
  @{
    FunctionName = "NahamReelsList"
    SourceFile   = "backend/aws/reelsList.js"
    Handler      = "reelsList.handler"
    ZipName      = "naham-reels-list.zip"
  },
  @{
    FunctionName = "NahamReelsSave"
    SourceFile   = "backend/aws/reelsSave.js"
    Handler      = "reelsSave.handler"
    ZipName      = "naham-reels-save.zip"
  },
  @{
    FunctionName = "NahamReelsDelete"
    SourceFile   = "backend/aws/reelsDelete.js"
    Handler      = "reelsDelete.handler"
    ZipName      = "naham-reels-delete.zip"
  },
  @{
    FunctionName = "NahamReelsUploadUrl"
    SourceFile   = "backend/aws/reelsUploadUrl.js"
    Handler      = "reelsUploadUrl.handler"
    ZipName      = "naham-reels-upload-url.zip"
  },
  @{
    FunctionName = "NahamDishesList"
    SourceFile   = "backend/aws/dishesList.js"
    Handler      = "dishesList.handler"
    ZipName      = "naham-dishes-list.zip"
  },
  @{
    FunctionName = "NahamDishesSave"
    SourceFile   = "backend/aws/dishesSave.js"
    Handler      = "dishesSave.handler"
    ZipName      = "naham-dishes-save.zip"
  },
  @{
    FunctionName = "NahamDishesUploadUrl"
    SourceFile   = "backend/aws/dishesUploadUrl.js"
    Handler      = "dishesUploadUrl.handler"
    ZipName      = "naham-dishes-upload-url.zip"
  },
  @{
    FunctionName = "NahamPricingSuggest"
    SourceFile   = "backend/aws/pricingSuggest.js"
    Handler      = "pricingSuggest.handler"
    ZipName      = "naham-pricing-suggest.zip"
  },
  @{
    FunctionName = "NahamOrdersList"
    SourceFile   = "backend/aws/ordersList.js"
    Handler      = "ordersList.handler"
    ZipName      = "naham-orders-list.zip"
  },
  @{
    FunctionName = "NahamOrdersCreate"
    SourceFile   = "backend/aws/ordersCreate.js"
    Handler      = "ordersCreate.handler"
    ZipName      = "naham-orders-create.zip"
  },
  @{
    FunctionName = "NahamOrdersUpdateStatus"
    SourceFile   = "backend/aws/ordersUpdateStatus.js"
    Handler      = "ordersUpdateStatus.handler"
    ZipName      = "naham-orders-update-status.zip"
  },
  @{
    FunctionName = "NahamPayoutsList"
    SourceFile   = "backend/aws/payoutsList.js"
    Handler      = "payoutsList.handler"
    ZipName      = "naham-payouts-list.zip"
  },
  @{
    FunctionName = "NahamChatConversations"
    SourceFile   = "backend/aws/chatConversations.js"
    Handler      = "chatConversations.handler"
    ZipName      = "naham-chat-conversations.zip"
  },
  @{
    FunctionName = "NahamChatMessages"
    SourceFile   = "backend/aws/chatMessages.js"
    Handler      = "chatMessages.handler"
    ZipName      = "naham-chat-messages.zip"
  },
  @{
    FunctionName = "NahamChatMarkRead"
    SourceFile   = "backend/aws/chatMarkRead.js"
    Handler      = "chatMarkRead.handler"
    ZipName      = "naham-chat-mark-read.zip"
  },
  @{
    FunctionName = "NahamNotificationsList"
    SourceFile   = "backend/aws/notificationsList.js"
    Handler      = "notificationsList.handler"
    ZipName      = "naham-notifications-list.zip"
  },
  @{
    FunctionName = "NahamNotificationsSave"
    SourceFile   = "backend/aws/notificationsSave.js"
    Handler      = "notificationsSave.handler"
    ZipName      = "naham-notifications-save.zip"
  },
  @{
    FunctionName = "NahamNotificationsMarkRead"
    SourceFile   = "backend/aws/notificationsMarkRead.js"
    Handler      = "notificationsMarkRead.handler"
    ZipName      = "naham-notifications-mark-read.zip"
  }
)

if (-not (Test-Path $OutputDir)) {
  New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$tempRoot = Join-Path $env:TEMP ("naham-lambda-pack-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
  foreach ($fn in $functions) {
    $source = Resolve-Path $fn.SourceFile
    $tempDir = Join-Path $tempRoot $fn.FunctionName
    New-Item -ItemType Directory -Path $tempDir | Out-Null

    $fileName = Split-Path -Leaf $source
    Copy-Item -LiteralPath $source -Destination (Join-Path $tempDir $fileName) -Force
    Copy-Item -LiteralPath $source -Destination (Join-Path $tempDir "index.js") -Force

    $zipPath = Join-Path (Resolve-Path $OutputDir) $fn.ZipName
    if (Test-Path $zipPath) {
      Remove-Item -LiteralPath $zipPath -Force
    }

    Compress-Archive -Path (Join-Path $tempDir "*") -DestinationPath $zipPath -Force

    Write-Output ("Built {0}" -f $zipPath)
    Write-Output ("  Lambda:  {0}" -f $fn.FunctionName)
    Write-Output ("  Handler: {0}" -f $fn.Handler)
    Write-Output ""
  }
}
finally {
  if (Test-Path $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
  }
}
