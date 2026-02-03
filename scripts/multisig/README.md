# Linera Multi-Owner Chain Creation Scripts

Scripts para crear y validar multi-owner chains en Linera Conway testnet.

## 🚀 Inicio Rápido

```bash
# Ejecutar script principal
./create_multisig.sh
```

## ✅ Requisitos

**Solo necesitas Linera CLI instalado**:

```bash
# Verificar
linera --version
```

Si no lo tienes, instala desde: https://linera.dev/developers/getting_started/index.html

## 📋 Scripts Disponibles

| Script | Propósito | Estado |
|--------|-----------|--------|
| `create_multisig.sh` | Crear multi-owner chain en Conway testnet | ✅ Funcional |
| `test_conway.sh` | Script simplificado de prueba | ✅ Funcional |

## 🔧 Características

- ✅ **Autocontenido**: No requiere configuración del repositorio
- ✅ **Temporal**: Crea su propio directorio de trabajo
- ✅ **Reproducible**: Mismo resultado en cada ejecución
- ✅ **Validado**: Probado en Conway testnet

## 📊 Resultados Esperados

```
Multi-Owner Chain ID: [64 hex chars]
Total chains: 3 (DEFAULT, ADMIN, Multi-Owner)
Sync time: ~700ms
Source balance: ~90 tokens
```

## 📖 Documentación Adicional

- [`REQUISITOS.md`](./REQUISITOS.md) - Detalle de dependencias
- [`../../docs/research/CONWAY_TESTNET_VALIDATION.md`](../../docs/research/CONWAY_TESTNET_VALIDATION.md) - Resultados de validación
- [`../../docs/research/CLI_COMMANDS_REFERENCE.md`](../../docs/research/CLI_COMMANDS_REFERENCE.md) - Referencia de comandos

## 🆘 Troubleshooting

**Error: `linera: command not found`**
- Instala Linera CLI desde la documentación oficial

**Error: `python3: command not found`**
- macOS: `brew install python3`
- Linux: `sudo apt install python3`

**Error: `client is not configured to propose`**
- Esto indica un problema interno del script, reporta el issue

## 📝 Notas

- El script se conecta a Conway testnet (no mainnet)
- No requiere fondos reales (usa faucet)
- Los datos temporales se guardan en `/tmp/`
- El wallet permanece en el directorio temporal para consultas futuras

---

**Last Updated**: February 3, 2026
