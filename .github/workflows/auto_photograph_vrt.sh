#!/bin/bash

# Android VRTテスト実行スクリプト
# 入力されたテスト名に一致するテストを実行します

# プロジェクトルートを自動検出（gradlewファイルがあるディレクトリを探す）
find_project_root() {
    local dir="$1"
    while [ "$dir" != "/" ]; do
        if [ -f "$dir/gradlew" ]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../AutoVrt" && pwd)"

if [ ! -f "$PROJECT_ROOT/gradlew" ]; then
    echo "エラー: gradlew が $PROJECT_ROOT に見つかりませんでした"
    exit 1
fi

cd "$PROJECT_ROOT" || exit 1
echo "プロジェクトルート: $PROJECT_ROOT"

TEST_DIR="app/src/test/java/com/example/autovrt"
PACKAGE="com.example.autovrt"

# テスト名の入力（引数または標準入力から取得）
if [ -n "$1" ]; then
    input_test_name="$1"
else
    echo "テスト名を入力してください:"
    read -r input_test_name
fi

# 入力が空の場合は終了
if [ -z "$input_test_name" ]; then
    echo "エラー: テスト名が入力されていません"
    exit 1
fi

echo "=== TEST_DIR 内のファイル一覧 ==="
ls -1 "$TEST_DIR"

for test_file in "$TEST_DIR"/*Test*.kt; do
    echo "検出ファイル: $test_file"
done

# テストファイルを検索
found_test=""
test_class_name=""
test_file_path=""

# ディレクトリ内のテストファイルを確認
for test_file in "$TEST_DIR"/*Test*.kt; do
    if [ ! -f "$test_file" ]; then
        continue
    fi

    # ファイル名から拡張子を除く
    filename=$(basename "$test_file" .kt)

    # ファイル内のクラス名を取得
    class_name=$(grep -E "^class [A-Za-z0-9_]+" "$test_file" | head -1 | sed -E 's/^class ([A-Za-z0-9_]+).*/\1/')

    # 入力がファイル名またはクラス名と一致するかチェック
    if [ "$input_test_name" = "$filename" ] || [ "$input_test_name" = "$class_name" ]; then
        found_test="$class_name"
        test_class_name="$class_name"
        test_file_path="$test_file"
        break
    fi
done

# テストが見つからない場合
if [ -z "$found_test" ]; then
    echo "エラー: テスト '$input_test_name' が見つかりませんでした"
    echo ""
    echo "利用可能なテスト一覧:"
    for test_file in "$TEST_DIR"/*Test*.kt; do
        if [ -f "$test_file" ]; then
            filename=$(basename "$test_file" .kt)
            class_name=$(grep -E "^class [A-Za-z0-9_]+" "$test_file" | head -1 | sed -E 's/^class ([A-Za-z0-9_]+).*/\1/')
            echo "  - $filename (クラス名: $class_name)"
        fi
    done
    exit 1
fi

# テストを実行
full_test_name="$PACKAGE.$test_class_name"
echo "テストを実行します: $full_test_name"
echo ""

./gradlew :androidApp:testDevelopDebugUnitTest --tests "$full_test_name"
TEST_EXIT_CODE=$?

# テスト結果XMLファイルのパス
test_results_dir="$PROJECT_ROOT/androidApp/build/test-results/testDevelopDebugUnitTest"
test_result_xml=""

# テスト結果XMLファイルを検索（ファイル名は TEST-${full_test_name}.xml 形式）
if [ -d "$test_results_dir" ]; then
    # 完全なテスト名（パッケージ.クラス名）でXMLファイルを検索
    test_result_xml=$(find "$test_results_dir" -name "TEST-${full_test_name}.xml" -type f | head -1)

    # 見つからない場合は、クラス名のみで検索（フォールバック）
    if [ -z "$test_result_xml" ]; then
        test_result_xml=$(find "$test_results_dir" -name "TEST-*${test_class_name}.xml" -type f | head -1)
    fi
fi

# 成功したテスト関数と失敗したテスト関数を抽出
passed_tests=()
failed_tests=()

if [ -n "$test_result_xml" ] && [ -f "$test_result_xml" ]; then
    # XMLファイルからすべてのtestcaseを抽出
    # 各行を処理して、testcaseタグからname属性を抽出

    current_testcase=""
    in_failure=0

    while IFS= read -r line; do
        # testcaseタグの開始を検出
        if echo "$line" | grep -q '<testcase'; then
            # name属性を抽出（awkを使用、最初のname属性を確実に抽出）
            test_method=$(echo "$line" | awk -F'name="' '{if(NF>1){split($2,a,"\""); print a[1]}}')

            # テストメソッド名が抽出できたか確認
            if [ -n "$test_method" ] && [ "$test_method" != "" ]; then
                # クラス名（パッケージ.クラス名）でないことを確認
                # テストメソッド名は通常、ドットを含まない
                if echo "$test_method" | grep -qv '\.'; then
                    current_testcase="$test_method"
                    in_failure=0

                    # 自己終了タグ（/>）で終わっている場合は成功
                    if echo "$line" | grep -q '/>$'; then
                        passed_tests+=("$current_testcase")
                        current_testcase=""
                    fi
                fi
            fi
        fi

        # failureタグを検出
        if [ -n "$current_testcase" ] && echo "$line" | grep -q '<failure'; then
            in_failure=1
        fi

        # testcaseタグの終了を検出
        if [ -n "$current_testcase" ] && echo "$line" | grep -q '</testcase>'; then
            if [ $in_failure -eq 1 ]; then
                failed_tests+=("$current_testcase")
            else
                passed_tests+=("$current_testcase")
            fi
            current_testcase=""
            in_failure=0
        fi
    done < "$test_result_xml"
else
    echo "警告: テスト結果XMLファイルが見つかりませんでした"
    echo "  検索パス: $test_results_dir"
    echo "  期待されるファイル名: TEST-${full_test_name}.xml"
    if [ -d "$test_results_dir" ]; then
        echo "  利用可能なXMLファイル:"
        find "$test_results_dir" -name "TEST-*.xml" -type f | head -5 | while read -r xml_file; do
            echo "    - $(basename "$xml_file")"
        done
    fi
    echo "テスト実行結果から個別の成功/失敗を判定できません"
fi

# 成功/失敗したテスト関数名を表示
echo ""
echo "=== テスト実行結果 ==="
if [ ${#passed_tests[@]} -gt 0 ]; then
    echo "✅ 成功したテスト関数 (${#passed_tests[@]}個):"
    for test_method in "${passed_tests[@]}"; do
        echo "  - $test_method"
    done
    echo ""
fi

if [ ${#failed_tests[@]} -gt 0 ]; then
    echo "❌ 失敗したテスト関数 (${#failed_tests[@]}個):"
    for test_method in "${failed_tests[@]}"; do
        echo "  - $test_method"
    done
    echo ""
fi

# 成功したテスト関数内のPNGファイルのみをコピー
if [ ${#passed_tests[@]} -gt 0 ]; then
    screenshots_dir="$PROJECT_ROOT/androidApp/__screenshots__"
    expected_dir="$PROJECT_ROOT/androidApp/.reg/expected"

    # expectedディレクトリが存在しない場合は作成
    mkdir -p "$expected_dir"

    # 成功したテスト関数内のPNGファイル名を抽出
    png_count=0
    copied_pngs=()

    for test_method in "${passed_tests[@]}"; do
        # テスト関数の開始行と終了行を特定
        # funキーワードで始まるテスト関数を検索（括弧をエスケープ）
        test_function_pattern="fun ${test_method}("

        # テスト関数の範囲を取得（次の@Testまたはfunまで）
        start_line=$(grep -n -F "$test_function_pattern" "$test_file_path" | head -1 | cut -d: -f1)

        if [ -n "$start_line" ]; then
            # 次の@Testまたはfunキーワードの行を探す（テスト関数の終了位置を推定）
            # macOS互換: 2つのgrepコマンドに分ける
            end_line=$(tail -n +$((start_line + 1)) "$test_file_path" | grep -n "^[[:space:]]*@Test" | head -1 | cut -d: -f1)
            if [ -z "$end_line" ]; then
                end_line=$(tail -n +$((start_line + 1)) "$test_file_path" | grep -n "^[[:space:]]*fun [a-zA-Z]" | head -1 | cut -d: -f1)
            fi

            if [ -z "$end_line" ]; then
                # 終了位置が見つからない場合はファイル末尾まで
                end_line=$(wc -l < "$test_file_path")
            else
                end_line=$((start_line + end_line - 1))
            fi

            # テスト関数内のPNGファイル名を抽出（サブシェルを避けるため、一時ファイルを使用）
            temp_png_file=$(mktemp)
            sed -n "${start_line},${end_line}p" "$test_file_path" | grep -oE '[A-Za-z0-9_]+\.png' > "$temp_png_file"

            while IFS= read -r png_name; do
                if [ -n "$png_name" ]; then
                    # 既にコピー済みかチェック
                    if [[ ! " ${copied_pngs[@]} " =~ " ${png_name} " ]]; then
                        source_png="$screenshots_dir/$png_name"

                        if [ -f "$source_png" ]; then
                            cp -f "$source_png" "$expected_dir/$png_name"
                            echo "コピーしました: $png_name (テスト関数: $test_method) -> $expected_dir/"
                            copied_pngs+=("$png_name")
                            png_count=$((png_count + 1))
                        else
                            echo "警告: $screenshots_dir/$png_name が見つかりませんでした (テスト関数: $test_method)"
                        fi
                    fi
                fi
            done < "$temp_png_file"

            rm -f "$temp_png_file"
        else
            echo "警告: テスト関数 '$test_method' が見つかりませんでした"
        fi
    done

    if [ $png_count -eq 0 ]; then
        echo "警告: 成功したテスト関数内に対応するPNGファイルが見つかりませんでした"
    else
        echo ""
        echo "合計 $png_count 個のPNGファイルをコピーしました（成功したテスト関数のみ）"
    fi
else
    echo "成功したテスト関数がないため、PNGファイルのコピーをスキップしました"
fi

exit $TEST_EXIT_CODE
