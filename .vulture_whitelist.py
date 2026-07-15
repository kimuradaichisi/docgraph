# vulture が誤検出する項目のホワイトリスト
# 使い方: vulture src/ .vulture_whitelist.py
#
# 例:
# _.upsert_many  # Protocol 定義で未使用と誤検出される
# _.find_by_source
