# backup — снапшоты каталогов в .eml

[![Release](https://img.shields.io/github/v/release/kostyk348/backup?sort=semver&color=blue)](https://github.com/kostyk348/backup/releases)
[![Last commit](https://img.shields.io/github/last-commit/kostyk348/backup?branch=master)](https://github.com/kostyk348/backup/commits/master)

Каталог → один `.eml`-контейнер (pack) с hash-chain; реестр снапшотов — tagdb
с тегами и временем; верификация целостности; ротация старых.

```bash
cargo build --release

backup init ~/.backups
backup snap ~/.backups ~/projects/vita --name vita_src --tag important --tag vita
backup list ~/.backups 'X-Tag == "important"'
backup verify ~/.backups <snap-file>     # hash-chain целостность
backup restore ~/.backups <snap-file> ~/restored
backup prune ~/.backups --older-than 604800   # ротация старше недели
```

## Свойства

- Снапшот = один `.eml` с байт-оффсетами и sha256-связкой (verify ловит порчу)
- Реестр в тегах: `X-Tag == "backup"`, пользовательские теги, X-Timestamp
- Restore защищён от path traversal (абсолютные пути и `..` отвергаются)
- Построен на [emlbox](https://github.com/kostyk348/mime-os) (MIME-OS)

## Тесты

```bash
cargo test
```
