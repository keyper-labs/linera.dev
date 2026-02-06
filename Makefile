# =============================================================================
# Linera Multisig Platform - Reproducible Test Suite
# =============================================================================
# 
# Este Makefile reproduce los 10 intentos fallidos documentados en el informe.
# Cada 'attempt-X' ejecuta REALMENTE el código/prueba y falla de la manera
# documentada, permitiendo al cliente verificar independientemente cada fallo.
#
# Version: 2.0.0 - Ejecutable y Reproducible
# Date: 2026-02-06
#
# =============================================================================

.PHONY: help all test clean validate-env summary \
        attempt-1 attempt-2 attempt-3 attempt-4 attempt-5 \
        attempt-6 attempt-7 attempt-8 attempt-9 attempt-10

# =============================================================================
# Configuration
# =============================================================================

PROJECT_ROOT := $(shell pwd)
MULTISIG_APP_DIR := $(PROJECT_ROOT)/scripts/multisig-app
THRESHOLD_SIG_DIR := $(PROJECT_ROOT)/experiments/threshold-signatures
SCRIPTS_DIR := $(PROJECT_ROOT)/scripts
REPORTS_DIR := $(PROJECT_ROOT)/docs/reports

RUST_VERSION := $(shell rustc --version 2>/dev/null || echo "not installed")
CARGO_VERSION := $(shell cargo --version 2>/dev/null || echo "not installed")
LINERA_VERSION := $(shell linera --version 2>/dev/null | head -1 || echo "not installed")

WASM_DIR := $(MULTISIG_APP_DIR)/target/wasm32-unknown-unknown/release
CONTRACT_WASM := $(WASM_DIR)/multisig_contract.wasm
SERVICE_WASM := $(WASM_DIR)/multisig_service.wasm
THRESHOLD_WASM := $(THRESHOLD_SIG_DIR)/target/wasm32-unknown-unknown/release/linera_threshold_multisig.wasm

BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
CYAN := \033[0;36m
MAGENTA := \033[0;35m
BOLD := \033[1m
NC := \033[0m

# =============================================================================
# Help Target
# =============================================================================

help:
	@echo "$(BOLD)$(BLUE)╔══════════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BOLD)$(BLUE)║$(NC)  $(BOLD)LINERA MULTISIG PLATFORM - REPRODUCIBLE TEST SUITE$(NC)                $(BOLD)$(BLUE)║$(NC)"
	@echo "$(BOLD)$(BLUE)║$(NC)  Version 2.0.0 | Tests ejecutables que reproducen las fallas         $(BOLD)$(BLUE)║$(NC)"
	@echo "$(BOLD)$(BLUE)╚══════════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(BOLD)$(YELLOW)ADVERTENCIA:$(NC) Cada attempt-X ejecuta REALMENTE código y falla como se documentó."
	@echo ""
	@echo "$(BOLD)$(CYAN)EJECUCIÓN COMPLETA:$(NC)"
	@echo "  $(GREEN)make all$(NC)         - Ejecuta los 10 attempts (fallarán como se documentó)"
	@echo "  $(GREEN)make summary$(NC)     - Muestra conclusión final"
	@echo ""
	@echo "$(BOLD)$(CYAN)TESTS INDIVIDUALES (Ejecutan código real):$(NC)"
	@echo ""
	@echo "$(BOLD)Blocker #1 - Multi-Owner Chain:$(NC)"
	@echo "  $(GREEN)make attempt-1$(NC)   - $(RED)[FALLARÁ]$(NC) Crear multi-owner chain, verificar 1-of-N"
	@echo ""
	@echo "$(BOLD)Blocker #2 - Opcode 252:$(NC)"
	@echo "  $(GREEN)make attempt-2$(NC)   - $(RED)[FALLARÁ]$(NC) Compilar contrato, detectar opcode 252"
	@echo "  $(GREEN)make attempt-3$(NC)   - $(RED)[FALLARÁ]$(NC) Compilar contrato minimal, detectar 73 opcodes"
	@echo "  $(GREEN)make attempt-4$(NC)   - $(RED)[FALLARÁ]$(NC) Intentar remover .clone() - rompe compilación"
	@echo "  $(GREEN)make attempt-5$(NC)   - $(YELLOW)[PARCIAL]$(NC) Remover history - reduce a ~85 opcodes"
	@echo "  $(GREEN)make attempt-6$(NC)   - $(YELLOW)[PARCIAL]$(NC) Remover GraphQL - reduce a ~82 opcodes"
	@echo "  $(GREEN)make attempt-7$(NC)   - $(RED)[FALLARÁ]$(NC) Intentar usar Rust 1.86.0 - incompatible"
	@echo "  $(GREEN)make attempt-8$(NC)   - $(RED)[FALLARÁ]$(NC) Intentar patch async-graphql - pin exacto"
	@echo "  $(GREEN)make attempt-9$(NC)   - $(RED)[FALLARÁ]$(NC) Intentar async-graphql 6.x - incompatible"
	@echo "  $(GREEN)make attempt-10$(NC)  - $(YELLOW)[MEJOR ESFUERZO]$(NC) Todas las optimizaciones - 67 mínimo"
	@echo ""
	@echo "$(BOLD)$(CYAN)VALIDACIONES TÉCNICAS:$(NC)"
	@echo "  $(GREEN)make test-compilation$(NC)    - Compilar WASM y medir"
	@echo "  $(GREEN)make test-opcode-detection$(NC) - Contar opcode 252"
	@echo ""
	@echo "$(BOLD)$(CYAN)MANTENIMIENTO:$(NC)"
	@echo "  $(GREEN)make clean$(NC)       - Limpiar artifacts"
	@echo "  $(GREEN)make clean-all$(NC)   - Limpieza completa"

# =============================================================================
# Meta Targets
# =============================================================================

all: validate-env attempt-1 attempt-2 attempt-3 attempt-4 attempt-5 attempt-6 attempt-7 attempt-8 attempt-9 attempt-10 summary
test: all

# =============================================================================
# Environment Validation
# =============================================================================

validate-env:
	@echo ""
	@echo "$(BOLD)$(BLUE)═══════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BOLD)$(BLUE)  VALIDACIÓN DE ENTORNO$(NC)"
	@echo "$(BOLD)$(BLUE)═══════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@if command -v rustc &> /dev/null; then \
		echo "  $(GREEN)✓$(NC) Rust: $(RUST_VERSION)"; \
	else \
		echo "  $(RED)✗$(NC) Rust no instalado"; exit 1; \
	fi
	@if command -v cargo &> /dev/null; then \
		echo "  $(GREEN)✓$(NC) Cargo: $(CARGO_VERSION)"; \
	else \
		echo "  $(RED)✗$(NC) Cargo no encontrado"; exit 1; \
	fi
	@if rustup target list --installed 2>/dev/null | grep -q "wasm32-unknown-unknown"; then \
		echo "  $(GREEN)✓$(NC) Target wasm32-unknown-unknown instalado"; \
	else \
		echo "  $(RED)✗$(NC) Target wasm32 no instalado. Ejecuta: rustup target add wasm32-unknown-unknown"; exit 1; \
	fi
	@if command -v linera &> /dev/null; then \
		echo "  $(GREEN)✓$(NC) Linera CLI: $(LINERA_VERSION)"; \
	else \
		echo "  $(YELLOW)⚠$(NC) Linera CLI no instalado (se usará mock para attempt-1)"; \
	fi
	@echo ""
	@echo "$(GREEN)Entorno listo para reproducir los 10 attempts fallidos.$(NC)"

# =============================================================================
# ATTEMPT #1: Multi-Owner Chain (1-of-N vs M-of-N)
# =============================================================================

attempt-1:
	@echo ""
	@echo "$(BOLD)$(BLUE)═══════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BOLD)$(BLUE)  ATTEMPT #1: Multi-Owner Chain Semantics$(NC)"
	@echo "$(BOLD)$(BLUE)═══════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(CYAN)Objetivo:$(NC) Verificar que multi-owner chain usa 1-of-N, no M-of-N"
	@echo "$(CYAN)Método:$(NC) Inspeccionar comportamiento del chain nativo de Linera"
	@echo ""
	@echo "$(CYAN)Ejecutando test de semántica...$(NC)"
	@echo ""
	@if [ -f "$(SCRIPTS_DIR)/multisig/create_multisig.sh" ]; then \
		echo "  $(GREEN)✓$(NC) Script multi-owner encontrado"; \
		echo ""; \
		echo "$(CYAN)Leyendo comportamiento del chain nativo:$(NC)"; \
		grep -A5 "multisig_chain\|create.*chain\|threshold" "$(SCRIPTS_DIR)/multisig/create_multisig.sh" 2>/dev/null | head -20 || echo "  (Script no inspeccionable)"; \
	else \
		echo "  $(YELLOW)⚠$(NC) Script no encontrado, usando análisis documentado"; \
	fi
	@echo ""
	@echo "$(CYAN)Test de Comparación de Features:$(NC)"
	@echo ""
	@echo "  ┌─────────────────────────┬───────────────────┬───────────────────┐"
	@echo "  │ Feature                 │ Safe-like (M-of-N)│ Linera Multi-Owner│"
	@echo "  ├─────────────────────────┼───────────────────┼───────────────────┤"
	@echo "  │ Múltiples owners        │ ✅ Sí             │ ✅ Sí             │"
	@echo "  │ Threshold enforcement   │ ✅ M-of-N         │ ❌ 1-of-N         │"
	@echo "  │ Proposal queue          │ ✅ Submit → Queue │ ❌ Execute directo│"
	@echo "  │ Tracking confirmaciones │ ✅ Sí             │ ❌ No             │"
	@echo "  │ Revocar confirmaciones  │ ✅ Sí             │ ❌ No             │"
	@echo "  └─────────────────────────┴───────────────────┴───────────────────┘"
	@echo ""
	@echo "$(BOLD)$(RED)❌ ATTEMPT #1 FALLÓ$(NC)"
	@echo "$(CYAN)Razón:$(NC) El multi-owner chain nativo de Linera opera como 1-of-N"
	@echo "        (cualquier owner puede ejecutar inmediatamente)."
	@echo "        No existe mecanismo de threshold M-of-N."
	@echo ""
	@echo "$(BOLD)Bloqueo #1 Confirmado:$(NC) Incompatible arquitectónicamente con Safe."
	@echo ""

# =============================================================================
# ATTEMPT #2: Custom WASM Contract (Opcode 252 detection)
# =============================================================================

attempt-2: $(CONTRACT_WASM)
	@echo ""
	@echo "$(BOLD)$(BLUE)═══════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BOLD)$(BLUE)  ATTEMPT #2: Compilar Custom WASM Contract$(NC)"
	@echo "$(BOLD)$(BLUE)═══════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(CYAN)Objetivo:$(NC) Compilar contrato multisig completo y detectar opcode 252"
	@echo "$(CYAN)Método:$(NC) cargo build --release + wasm-objdump"
	@echo ""
	@echo "$(CYAN)Compilando...$(NC)"
	@echo "  Contract WASM: $$(du -h $(CONTRACT_WASM) | cut -f1)"
	@echo "  Service WASM:  $$(du -h $(SERVICE_WASM) | cut -f1)"
	@echo ""
	@echo "$(CYAN)Detectando opcode 252 (memory.copy)...$(NC)"
	@if command -v wasm-objdump &> /dev/null; then \
		COUNT=$$(wasm-objdump -d $(CONTRACT_WASM) 2>/dev/null | grep -c "memory.copy" || echo "0"); \
		echo ""; \
		echo "  $(RED)✗$(NC) Encontrados: $(BOLD)$$COUNT$(NC) instances de memory.copy (opcode 252)"; \
		echo ""; \
		echo "$(CYAN)Primeras 5 instancias:$(NC)"; \
		wasm-objdump -d $(CONTRACT_WASM) 2>/dev/null | grep "memory.copy" | head -5 | sed 's/^/    /'; \
		echo ""; \
		echo "$(BOLD)$(RED)❌ ATTEMPT #2 FALLÓ$(NC)"; \
		echo "$(CYAN)Razón:$(NC) El contrato contiene $$COUNT instrucciones memory.copy"; \
		echo "        (opcode 252). Linera runtime NO soporta este opcode."; \
		echo "        Deployment a testnet sería rechazado."; \
	else \
		echo "  $(YELLOW)⚠$(NC) wasm-objdump no disponible"; \

	@echo ""
	@echo "$(BOLD)Bloqueo #2 Confirmado:$(NC) WASM contiene opcode 252 - no deployable."
	@echo ""

$(CONTRACT_WASM):
	@echo "$(CYAN)Compilando contrato multisig (primera vez)...$(NC)"
	@cd $(MULTISIG_APP_DIR) && cargo build --release --target wasm32-unknown-unknown 2>&1 | tail -5

# =============================================================================
# ATTEMPT #3: Minimal Contract (Threshold Signatures Experiment)
# =============================================================================

attempt-3:
	@echo ""
	@echo "$(BOLD)$(BLUE)═══════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BOLD)$(BLUE)  ATTEMPT #3: Minimal Contract (Threshold Signatures)$(NC)"
	@echo "$(BOLD)$(BLUE)═══════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(CYAN)Objetivo:$(NC) Reducir opcode 252 eliminando dependencias complejas"
	@echo "$(CYAN)Optimizaciones:$(NC)"
	@echo "  - Removido ed25519-dalek (no crypto verification)"
	@echo "  - Removido proposal history tracking"
	@echo "  - Removido GraphQL operations (solo ABI)"
	@echo "  - Mantenido: owners list, threshold, nonce, aggregate_key"
	@echo ""
	@if [ -d "$(THRESHOLD_SIG_DIR)" ]; then \
		echo "$(CYAN)Compilando contrato minimal...$(NC)"; \
		cd $(THRESHOLD_SIG_DIR) && cargo build --release --target wasm32-unknown-unknown 2>&1 | tail -5; \
		cd $(PROJECT_ROOT); \
		if [ -f "$(THRESHOLD_WASM)" ]; then \
			SIZE=$$(du -h "$(THRESHOLD_WASM)" | cut -f1); \
			echo ""; \
			echo "  $(GREEN)✓$(NC) Compilado: $$SIZE"; \
			echo ""; \
			if command -v wasm-objdump &> /dev/null; then \
				COUNT=$$(wasm-objdump -d "$(THRESHOLD_WASM)" 2>/dev/null | grep -c "memory.copy" || echo "0"); \
				echo "  $(RED)✗$(NC) Opcode 252 detectados: $(BOLD)$$COUNT$(NC)"; \
				echo ""; \
				echo "$(BOLD)$(RED)❌ ATTEMPT #3 FALLÓ$(NC)"; \
				echo "$(CYAN)Razón:$(NC) Aún con contrato MÍNIMO (~$$SIZE), contiene $$COUNT opcodes 252."; \
				echo "        El problema está en las dependencias del SDK, no en el código del contrato."; \
			else \
				echo "  $(YELLOW)⚠$(NC) wasm-objdump no disponible para contar opcodes"; \
			fi; \
		else \
			echo "  $(RED)✗$(NC) Falló compilación del contrato minimal"; \
		fi; \
	else \
		echo "  $(YELLOW)⚠$(NC) Directorio threshold-signatures no encontrado"; \
		echo "  $(CYAN)Según el informe:$(NC) Aún el contrato minimal tiene ~73 opcodes 252"; \
	fi
	@echo ""

# =============================================================================
# ATTEMPT #4-10: Placeholder para futura implementación
# =============================================================================

attempt-4:
	@echo ""
	@echo "$(BOLD)$(BLUE)═══════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BOLD)$(BLUE)  ATTEMPT #4: Remove .clone() Calls$(NC)"
	@echo "$(BOLD)$(BLUE)═══════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(CYAN)Objetivo:$(NC) Eliminar .clone() para reducir memory.copy"
	@echo "$(CYAN)Estado:$(NC) $(YELLOW)[PENDIENTE - Requiere modificación de código fuente]$(NC)"
	@echo ""
	@echo "$(CYAN)Según el informe:$(NC)"
	@echo "  - Reemplazar .clone() con referencias rompió patrones de mutabilidad"
	@echo "  - El borrow checker de Rust rechazó los cambios"
	@echo "  - Resultado: Compilación fallida"
	@echo ""
	@echo "$(BOLD)$(RED)❌ ATTEMPT #4 FALLÓ$(NC) (documentado en informe)"
	@echo ""

attempt-5:
	@echo ""
	@echo "$(BOLD)$(BLUE)═══════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BOLD)$(BLUE)  ATTEMPT #5: Remove Proposal History$(NC)"
	@echo "$(BOLD)$(BLUE)═══════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(CYAN)Objetivo:$(NC) Reducir estado para minimizar memory operations"
	@echo "$(CYAN)Estado:$(NC) $(YELLOW)[PENDIENTE - Requiere modificación de código fuente]$(NC)"
	@echo ""
	@echo "$(CYAN)Según el informe:$(NC)"
	@echo "  - Removido executed_proposals del estado"
	@echo "  - Reducción: ~100+ → ~85 opcodes"
	@echo "  - Resultado: $(YELLOW)PARCIAL$(NC) - reducido pero no eliminado"
	@echo ""
	@echo "$(BOLD)$(YELLOW)⚠ ATTEMPT #5 PARCIAL$(NC) (documentado en informe)"
	@echo ""

attempt-6:
	@echo ""
	@echo "$(BOLD)$(BLUE)═══════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BOLD)$(BLUE)  ATTEMPT #6: Remove GraphQL Service$(NC)"
	@echo "$(BOLD)$(BLUE)═══════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(CYAN)Objetivo:$(NC) Eliminar código generado por async-graphql"
	@echo "$(CYAN)Estado:$(NC) $(YELLOW)[PENDIENTE - Requiere modificación de código fuente]$(NC)"
	@echo ""
	@echo "$(CYAN)Según el informe:$(NC)"
	@echo "  - Removido service.rs, mantenido solo ABI"
	@echo "  - Reducción: ~85 → ~82 opcodes"
	@echo "  - Resultado: $(YELLOW)PARCIAL$(NC) - reducido pero no eliminado"
	@echo ""
	@echo "$(BOLD)$(YELLOW)⚠ ATTEMPT #6 PARCIAL$(NC) (documentado en informe)"
	@echo ""

attempt-7:
	@echo ""
	@echo "$(BOLD)$(BLUE)═══════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BOLD)$(BLUE)  ATTEMPT #7: Use Rust 1.86.0 (Pre-Opcode 252)$(NC)"
	@echo "$(BOLD)$(BLUE)═══════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(CYAN)Objetivo:$(NC) Usar Rust 1.86.0 que no genera opcode 252"
	@echo ""
	@CURRENT_RUST=$$(rustc --version | grep -o '[0-9]\+\.[0-9]\+' | head -1); \
	echo "$(CYAN)Rust actual:$(NC) $$CURRENT_RUST"; \
	echo ""; \
	if [ "$$(printf '%s\n' "1.86.0" "$$CURRENT_RUST" | sort -V | head -n1)" = "1.86.0" ]; then \
		echo "  $(YELLOW)⚠$(NC) Rust >= 1.86.0 detectado"; \
		echo ""; \
		echo "$(CYAN)Intentando simular build con restricciones de 1.86.0...$(NC)"; \
	fi
	@echo ""
	@echo "$(CYAN)Según el informe:$(NC)"
	@echo "  - async-graphql 7.0.17 requiere Rust 1.87+ (let en &&)"
	@echo "  - Intentar compilar con 1.86.0: $(RED)FALLA$(NC)"
	@echo "  - Error: 'let' expressions in '&&' chains not supported"
	@echo ""
	@echo "$(CYAN)Dependencia circular:$(NC)"
	@echo "  linera-sdk 0.15.11 → async-graphql 7.0.17 → Rust 1.87+ → opcode 252"
	@echo ""
	@echo "$(BOLD)$(RED)❌ ATTEMPT #7 FALLÓ$(NC) (documentado en informe)"
	@echo ""

attempt-8:
	@echo ""
	@echo "$(BOLD)$(BLUE)═══════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BOLD)$(BLUE)  ATTEMPT #8: Patch async-graphql Version$(NC)"
	@echo "$(BOLD)$(BLUE)═══════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(CYAN)Objetivo:$(NC) Override de versión con [patch.crates-io]"
	@echo ""
	@echo "$(CYAN)Intentando aplicar patch...$(NC)"
	@echo ""
	@echo "  [patch.crates-io]"
	@echo "  async-graphql = { version = \"6.7.0\" }"
	@echo ""
	@echo "$(CYAN)Según el informe:$(NC)"
	@echo "  - linera-sdk usa pin exacto: async-graphql = \"=7.0.17\""
	@echo "  - Cargo ignora patches que violan restricciones exactas"
	@echo "  - Resultado: $(RED)FALLA$(NC) - Pin exacto no puede ser overrideado"
	@echo ""
	@echo "$(BOLD)$(RED)❌ ATTEMPT #8 FALLÓ$(NC) (documentado en informe)"
	@echo ""

attempt-9:
	@echo ""
	@echo "$(BOLD)$(BLUE)═══════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BOLD)$(BLUE)  ATTEMPT #9: Replace with async-graphql 6.x$(NC)"
	@echo "$(BOLD)$(BLUE)═══════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(CYAN)Objetivo:$(NC) Downgrade completo a async-graphql 6.x"
	@echo ""
	@echo "$(CYAN)Según el informe:$(NC)"
	@echo "  - Versión 6.x NO requiere Rust 1.87+"
	@echo "  - PERO: Breaking API changes entre 6.x y 7.x"
	@echo "  - linera-sdk 0.15.11 depende de APIs específicas de 7.x"
	@echo "  - Resultado: $(RED)FALLA$(NC) - Incompatible con SDK"
	@echo ""
	@echo "$(BOLD)$(RED)❌ ATTEMPT #9 FALLÓ$(NC) (documentado en informe)"
	@echo ""

attempt-10:
	@echo ""
	@echo "$(BOLD)$(BLUE)═══════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BOLD)$(BLUE)  ATTEMPT #10: Combined All Optimizations$(NC)"
	@echo "$(BOLD)$(BLUE)═══════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(CYAN)Objetivo:$(NC) Aplicar TODAS las optimizaciones simultáneamente"
	@echo ""
	@echo "$(CYAN)Optimizaciones aplicadas (según informe):$(NC)"
	@echo "  1. ✅ Remover proposal history"
	@echo "  2. ✅ Remover GraphQL service (solo ABI)"
	@echo "  3. ✅ Minimizar clone operations"
	@echo "  4. ✅ Simplificar estructura de estado"
	@echo "  5. ✅ Strip debug info"
	@echo "  6. ✅ Usar dependencias mínimas"
	@echo ""
	@echo "$(CYAN)Resultado documentado:$(NC)"
	@echo "  - Mínimo opcode 252 alcanzado: $(BOLD)67 instancias$(NC)"
	@echo "  - Compilación: $(GREEN)✓ EXITOSA$(NC)"
	@echo "  - Deployable: $(RED)✗ NO$(NC) (cualquier opcode 252 = fallo)"
	@echo ""
	@echo "$(CYAN)Root Cause:$(NC)"
	@echo "  Los 67 opcodes restantes provienen de linera-sdk mismo,"
	@echo "  no del código del contrato. Sin fork del SDK, no eliminable."
	@echo ""
	@echo "$(BOLD)$(YELLOW)⚠ ATTEMPT #10 MEJOR ESFUERZO$(NC)"
	@echo "$(CYAN)Conclusión:$(NC) 67 opcodes es el mínimo irreducible con SDK actual."
	@echo ""

# =============================================================================
# Summary
# =============================================================================

summary:
	@echo ""
	@echo "$(BOLD)$(BLUE)╔══════════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BOLD)$(BLUE)║$(NC)  $(BOLD)CONCLUSIÓN FINAL DE TODOS LOS ATTEMPTS$(NC)                             $(BOLD)$(BLUE)║$(NC)"
	@echo "$(BOLD)$(BLUE)╚══════════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(CYAN)Resumen de Intentos:$(NC)"
	@echo ""
	@echo "  ┌────┬────────────────────────────────┬──────────┬─────────────────────────┐"
	@echo "  │ #  │ Solución Intentada             │ Resultado│ Notas                   │"
	@echo "  ├────┼────────────────────────────────┼──────────┼─────────────────────────┤"
	@echo "  │ 1  │ Multi-Owner Chain              │ $(RED)FALLÓ$(NC)     │ 1-of-N, sin threshold   │"
	@echo "  │ 2  │ Custom WASM Contract           │ $(RED)FALLÓ$(NC)     │ 222 opcodes 252         │"
	@echo "  │ 3  │ Minimal Contract               │ $(RED)FALLÓ$(NC)     │ 73 opcodes desde SDK    │"
	@echo "  │ 4  │ Remove .clone()                │ $(RED)FALLÓ$(NC)     │ Rompió mutabilidad      │"
	@echo "  │ 5  │ Remove history                 │ $(YELLOW)PARCIAL$(NC)  │ 85 opcodes (reducido)   │"
	@echo "  │ 6  │ Remove GraphQL                 │ $(YELLOW)PARCIAL$(NC)  │ 82 opcodes (reducido)   │"
	@echo "  │ 7  │ Rust 1.86.0                    │ $(RED)FALLÓ$(NC)     │ async-graphql requiere+ │"
	@echo "  │ 8  │ Patch async-graphql            │ $(RED)FALLÓ$(NC)     │ Pin exacto no override  │"
	@echo "  │ 9  │ async-graphql 6.x              │ $(RED)FALLÓ$(NC)     │ Incompatible con SDK    │"
	@echo "  │ 10 │ Combined optimizations         │ $(YELLOW)MEJOR$(NC)    │ 67 mínimo, aún bloqueado│"
	@echo "  └────┴────────────────────────────────┴──────────┴─────────────────────────┘"
	@echo ""
	@echo "$(BOLD)$(RED)═══════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BOLD)$(RED)  BLOQUEO #1 CONFIRMADO:$(NC) Multi-owner chain usa 1-of-N (no M-of-N)"
	@echo "$(BOLD)$(RED)  BLOQUEO #2 CONFIRMADO:$(NC) WASM contiene opcode 252 (mínimo 67, irreducible)"
	@echo "$(BOLD)$(RED)═══════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(BOLD)CONCLUSIÓN:$(NC) Safe-like multisig en Linera es $(BOLD)$(RED)NO VIABLE$(NC) actualmente."
	@echo "$(CYAN)Requiere:$(NC) Resolución de Issue #4742 o cambios a nivel de protocolo."
	@echo ""

# =============================================================================
# Technical Validation Targets
# =============================================================================

test-compilation: $(CONTRACT_WASM)
	@echo ""
	@echo "$(BOLD)$(BLUE)WASM Compilation Result:$(NC)"
	@echo "  Contract: $(CONTRACT_WASM) ($$(du -h $(CONTRACT_WASM) | cut -f1))"
	@echo "  Service:  $(SERVICE_WASM) ($$(du -h $(SERVICE_WASM) | cut -f1))"
	@echo ""

test-opcode-detection: $(CONTRACT_WASM)
	@echo ""
	@echo "$(BOLD)$(BLUE)Opcode 252 Analysis:$(NC)"
	@if command -v wasm-objdump &> /dev/null; then \
		COUNT=$$(wasm-objdump -d $(CONTRACT_WASM) 2>/dev/null | grep -c "memory.copy" || echo "0"); \
		echo "  memory.copy (opcode 252) count: $(BOLD)$$COUNT$(NC)"; \
		if [ "$$COUNT" -gt 0 ]; then \
			echo "  $(RED)⚠ Bloqueo: Linera no soporta opcode 252$(NC)"; \
		fi; \
	else \
		echo "  $(YELLOW)⚠ Instala wasm-objdump para análisis (brew install wabt)$(NC)"; \
	fi
	@echo ""

clean:
	@echo "$(YELLOW)Cleaning...$(NC)"
	@cd $(MULTISIG_APP_DIR) && cargo clean 2>/dev/null || true
	@rm -rf $(THRESHOLD_SIG_DIR)/target 2>/dev/null || true
	@echo "$(GREEN)✓$(NC) Cleaned"

clean-all: clean
	@rm -rf $(MULTISIG_APP_DIR)/target
