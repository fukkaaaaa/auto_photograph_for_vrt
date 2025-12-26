#!/bin/bash

# VRTテストを実行するスクリプト
# 引数: テストクラス名（例: "GreetingScreenTest"）

TEST_NAME="$1"

if [ -z "$TEST_NAME" ]; then
    echo "❌ エラー: テストクラス名が指定されていません"
    echo "使用方法: $0 <テストクラス名>"
    exit 1
fi

echo "🚀 VRTテストを実行します: $TEST_NAME"

# テストを実行
./gradlew :app:testDebugUnitTest --tests "*${TEST_NAME}*" || {
    echo "⚠️ テストの実行中にエラーが発生しましたが、続行します"
}

# 生成された画像を正解画像ディレクトリに移動
SCREENSHOTS_DIR="app/__screenshots__"
EXPECTED_DIR="app/.reg/expected"

if [ -d "$SCREENSHOTS_DIR" ]; then
    echo "📁 生成された画像を正解画像ディレクトリに移動中..."
    
    # 正解画像ディレクトリを作成
    mkdir -p "$EXPECTED_DIR"
    
    # 画像をコピー
    find "$SCREENSHOTS_DIR" -name "*.png" -exec cp {} "$EXPECTED_DIR/" \;
    
    echo "✅ 画像の移動が完了しました"
else
    echo "⚠️ スクリーンショットディレクトリが見つかりません: $SCREENSHOTS_DIR"
fi

echo "✅ VRTテストの実行が完了しました"

