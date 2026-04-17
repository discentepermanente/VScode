#!/bin/bash

# ++++++++++++++++++++++++++++++++++++++++++++++ #
# Script para instalar VScode en Ubuntu.
# Incluye herramientas: 
#   Live Server
#   Indent-rainbow
#   HTML CSS Support
#   Prettier-Code formatter
#   ESlint
#   Material Icon Theme
#   Github Copilot Chat
# Puede modificarse para adaptarlo a necesidades
# particulares:   Fidel Chávez ======> CopyLeft
# ++++++++++++++++++++++++++++++++++++++++++++++ #

# DETECCIÓN DE USUARIO Y PRIVILEGIOS

# Detectar si se ejecuta como root
if [ "$EUID" -eq 0 ]; then
    # Obtener el usuario real que ejecutó sudo
    REAL_USER="${SUDO_USER:-$USER}"
    REAL_HOME=$(eval echo ~$REAL_USER)
    
    # Verificar que no sea root el usuario real
    if [ "$REAL_USER" = "root" ]; then
        echo "Error: No ejecutes este script directamente como root"
        echo "   Usa: sudo $0"
        exit 1
    fi
    
    echo "Configurando VS Code para el usuario: $REAL_USER"
    echo "Home del usuario: $REAL_HOME"
    echo ""
else
    echo "Error: Este script debe ejecutarse con sudo"
    echo "   Ejecuta: sudo $0"
    exit 1
fi

# FUNCIONES AUXILIARES

# Función para ejecutar comandos como usuario real
run_as_user() {
    sudo -u "$REAL_USER" "$@"
}

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función idempotente para eliminar bloqueos de apt
elimina_bloqueos() { 
    echo "Verificando bloqueos de apt..."
    for lock in /var/lib/dpkg/lock-frontend \
                /var/cache/apt/archives/lock \
                /var/lib/apt/lists/lock \
                /var/lib/dpkg/lock; do
        if [ -f "$lock" ]; then
            # Verificar si el proceso sigue vivo
            if ! lsof "$lock" >/dev/null 2>&1; then
                rm -f "$lock"
                echo "Eliminado: $lock"
            else
                echo "Bloqueo en uso: $lock"
            fi
        fi
    done
}

# Función idempotente: HTTP → HTTPS
http_a_https() {
    local MARKER="/etc/apt/.http-to-https-converted"
    
    # Verificar si ya se realizó la conversión
    if [ -f "$MARKER" ]; then
        echo "ⓘ  La conversión HTTP→HTTPS ya se realizó anteriormente"
        echo "   Para forzar: sudo rm $MARKER"
        return 0
    fi
    
    echo "Verificando repositorios HTTP..."
    
    # Directorio de respaldo con timestamp
    local D="/tmp/apt-backup-$(date +%s)"
    mkdir -p "$D" || return 1
    
    # Encontrar archivos .list y .sources
    local ARCHIVOS=$(find /etc/apt -type f \( -name "*.list" -o -name "*.sources" \) 2>/dev/null)
    [ -f "/etc/apt/sources.list" ] && ARCHIVOS="/etc/apt/sources.list $ARCHIVOS"
    
    # Contar cuántos archivos tienen HTTP
    local TOTAL_HTTP=$(grep -h "http://" $ARCHIVOS 2>/dev/null | wc -l)
    
    if [ "$TOTAL_HTTP" -eq 0 ]; then
        echo "ⓘ  Todos los repositorios ya usan HTTPS"
        touch "$MARKER"
        return 0
    fi
    
    echo "Convirtiendo $TOTAL_HTTP entradas HTTP→HTTPS..."
    
    # Convertir cada archivo
    for f in $ARCHIVOS; do
        if [ -f "$f" ]; then
            cp "$f" "$D/" || return 1
            sed -i 's|http://|https://|g' "$f" || return 1
        fi
    done
    
    # Actualizar sistema
    apt update && apt full-upgrade -y
    
    # Limpiar sistema
    apt -y autoremove 2>/dev/null || true
    apt clean 2>/dev/null || true
    apt autoclean 2>/dev/null || true
    
    # Marcar como completado
    touch "$MARKER"
    
    echo "Conversión completada - Respaldo: $D"
    sleep 2
}

# Función idempotente: Instalar VS Code
instalar_vscode() {
    echo "Instalando VS Code oficial..."
    
    # Verificar si VS Code ya está instalado
    if command_exists code; then
        local VERSION=$(run_as_user code --version 2>/dev/null | head -1)
        echo "VS Code ya está instalado: $VERSION"
        return 0
    fi

    # Instalar dependencias (solo si no están)
    local PAQUETES=("wget" "gpg" "software-properties-common" "lsof")
    local INSTALAR=()
    
    for pkg in "${PAQUETES[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            INSTALAR+=("$pkg")
        fi
    done
    
    if [ ${#INSTALAR[@]} -gt 0 ]; then
        echo "   Instalando dependencias: ${INSTALAR[*]}"
        apt install -y "${INSTALAR[@]}"
    fi

    # Importar clave GPG de Microsoft (solo si no existe)
    if [ ! -f "/etc/apt/trusted.gpg.d/microsoft.asc" ]; then
        echo "   Importando clave GPG de Microsoft..."
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | tee /etc/apt/trusted.gpg.d/microsoft.asc > /dev/null
    fi

    # Agregar repositorio (solo si no existe)
    if [ ! -f "/etc/apt/sources.list.d/vscode.list" ]; then
        echo "   Agregando repositorio de VS Code..."
        echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
        apt update
    else
        echo "   ⓘ Repositorio ya configurado"
    fi

    # Instalar VS Code
    echo "   Instalando VS Code..."
    apt install -y code
    
    echo "VS Code instalado exitosamente"
}

# Función idempotente: Configurar VS Code
configurar_vscode() {
    # Verificar que VS Code está instalado
    if ! command_exists code; then
        echo "VS Code no está instalado"
        return 1
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   CONFIGURANDO VS CODE para $REAL_USER"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # ============================================
    # 1. CREAR DIRECTORIOS
    # ============================================
    echo "1. Preparando directorios..."
    run_as_user mkdir -p "$REAL_HOME/.config/Code/User"
    run_as_user mkdir -p "$REAL_HOME/.vscode/extensions"
    echo "Directorios listos"
    echo ""

    # ============================================
    # 2. CREAR CONFIGURACIÓN (solo si no existe)
    # ============================================
    echo "2. Creando configuración..."
    
    if ! run_as_user test -f "$REAL_HOME/.config/Code/User/settings.json"; then
        run_as_user tee "$REAL_HOME/.config/Code/User/settings.json" > /dev/null << 'EOF'
{
    "locale": "es",
    "workbench.iconTheme": "material-icon-theme",
    "workbench.colorTheme": "Default Dark+",
    "editor.fontSize": 14,
    "editor.fontFamily": "'Fira Code', 'Cascadia Code', monospace",
    "editor.fontLigatures": true,
    "editor.tabSize": 4,
    "editor.renderWhitespace": "all",
    "files.autoSave": "afterDelay",
    "telemetry.telemetryLevel": "off",
    "telemetry.enableTelemetry": false,
    "telemetry.enableCrashReporter": false,
    "telemetry.feedback.enabled": false,
    "extensions.ignoreRecommendations": true,
    "extensions.autoCheckUpdates": false,
    "extensions.autoUpdate": false,
    "settingsSync.enabled": false,
    "prettier.singleQuote": true,
    "prettier.semi": false,
    "eslint.validate": ["javascript", "javascriptreact", "html"],
    "liveServer.settings.donotShowInfoMsg": true,
    "[html]": {
        "editor.defaultFormatter": "esbenp.prettier-vscode",
        "editor.formatOnSave": true
    },
    "[css]": {
        "editor.defaultFormatter": "esbenp.prettier-vscode",
        "editor.formatOnSave": true
    },
    "[javascript]": {
        "editor.defaultFormatter": "esbenp.prettier-vscode",
        "editor.formatOnSave": true
    },
    "github.copilot.enable": true,
    "github.copilot.chat.enable": true,
    "github.copilot.enableTelemetry": false
}
EOF
        echo "Configuración creada"
    else
        echo "ⓘ La configuración ya existe (no se modificó)"
    fi
    echo ""

    # ============================================
    # 3. INSTALAR EXTENSIONES (solo las que faltan)
    # ============================================
    echo "3. Instalando extensiones..."
    
    declare -a EXTENSIONES=(
        "ms-ceintl.vscode-language-pack-es"
        "ritwickdey.LiveServer"
        "oderwat.indent-rainbow"
        "ecmel.vscode-html-css"
        "esbenp.prettier-vscode"
        "dbaeumer.vscode-eslint"
        "PKief.material-icon-theme"
        "GitHub.copilot-chat"
    )
    
    # Obtener extensiones ya instaladas
    local INSTALADAS=""
    if run_as_user test -f "$REAL_HOME/.vscode/extensions/extensions.json"; then
        INSTALADAS=$(run_as_user code --list-extensions 2>/dev/null || echo "")
    fi
    
    local nuevas=0
    local existentes=0
    
    for extension in "${EXTENSIONES[@]}"; do
        if echo "$INSTALADAS" | grep -q "^$extension$"; then
            echo "Ya instalada: $extension"
            existentes=$((existentes + 1))
        else
            echo "Instalando: $extension"
            if run_as_user code --install-extension "$extension" --force >/dev/null 2>&1; then
                echo "Instalada: $extension"
                nuevas=$((nuevas + 1))
            else
                echo "Falló: $extension (se intentará en la primera ejecución)"
            fi
        fi
    done
    
    echo "Resumen: $existentes existentes, $nuevas nuevas instaladas"
    echo ""

    # 4. CONFIGURAR ARGV.JSON (evitar warnings)
    echo "4. Configurando argv.json..."
    
    if ! run_as_user test -f "$REAL_HOME/.config/Code/argv.json"; then
        run_as_user tee "$REAL_HOME/.config/Code/argv.json" > /dev/null << 'EOF'
// This configuration file allows you to pass permanent command line arguments to VS Code.
{
    "disable-hardware-acceleration": false,
    "enable-crash-reporter": false
}
EOF
        echo "argv.json creado"
    else
        echo "ⓘ argv.json ya existe"
    fi
    echo ""

    # 5. BLOQUEO DE DOMINIOS (telemetría) - MODIFICADO
    echo "5. Bloqueando dominios de telemetría..."
    
    # Lista completa de dominios a bloquear
    declare -a DOMINIOS_BLOQUEAR=(
        "# BLOQUEO TELEMETRIA VS CODE"
        ""
        "# Microsoft telemetry"
        "0.0.0.0 telemetry.microsoft.com"
        "0.0.0.0 telemetry.firstpartyapps.microsoft.com"
        "0.0.0.0 vortex.data.microsoft.com"
        "0.0.0.0 vortex-win.data.microsoft.com"
        "0.0.0.0 settings-win.data.microsoft.com"
        "0.0.0.0 watson.telemetry.microsoft.com"
        "0.0.0.0 az418426.vo.msecnd.net"
        "0.0.0.0 mobile.pipe.aria.microsoft.com"
        "0.0.0.0 metrics.data.microsoft.com"
        "0.0.0.0 v20.events.data.microsoft.com"
        "0.0.0.0 dc.services.visualstudio.com"
        "0.0.0.0 vscodemetrics.azureedge.net"
        "0.0.0.0 vscode-sync.trafficmanager.net"
        ""
        "# GitHub/Copilot telemetry"
        "0.0.0.0 api.github.com"
        "0.0.0.0 copilot-telemetry.githubusercontent.com"
        "0.0.0.0 copilot-proxy.githubusercontent.com"
        ""
        "# Google Analytics"
        "0.0.0.0 www.google-analytics.com"
        "0.0.0.0 ssl.google-analytics.com"
        "0.0.0.0 google-analytics.com"
        ""
        "# Other tracking"
        "0.0.0.0 app-measurement.com"
        "0.0.0.0 crashlytics.com"
        "0.0.0.0 sentry.io"
        "0.0.0.0 segment.io"
        "0.0.0.0 mixpanel.com"
        "0.0.0.0 amplitude.com"
    )
    
    # Verificar si ya existe el bloqueo
    if ! grep -q "# BLOQUEO TELEMETRIA VS CODE" /etc/hosts 2>/dev/null; then
        # No existe ningún bloqueo, agregar todo
        echo "   Agregando bloqueo completo de telemetría..."
        {
            echo ""
            echo "# BLOQUEO TELEMETRIA VS CODE"
            for dominio in "${DOMINIOS_BLOQUEAR[@]}"; do
                echo "$dominio"
            done
        } >> /etc/hosts
        echo "Todos los dominios bloqueados ($((${#DOMINIOS_BLOQUEAR[@]} - 5)) dominios)"
    else
        # Ya existe bloqueo, verificar y agregar los que faltan
        echo "   Verificando dominios faltantes..."
        local NUEVOS=0
        
        for dominio in "${DOMINIOS_BLOQUEAR[@]}"; do
            # Saltar líneas vacías y comentarios
            if [[ -z "$dominio" ]] || [[ "$dominio" == \#* ]]; then
                continue
            fi
            
            # Verificar si el dominio ya está bloqueado
            if ! grep -q "^0.0.0.0 ${dominio#0.0.0.0 }" /etc/hosts 2>/dev/null; then
                echo "0.0.0.0 ${dominio#0.0.0.0 }" >> /etc/hosts
                echo "   ➕ Agregado: ${dominio#0.0.0.0 }"
                NUEVOS=$((NUEVOS + 1))
            fi
        done
        
        if [ $NUEVOS -eq 0 ]; then
            echo "Todos los dominios ya estaban bloqueados"
        else
            echo "Se agregaron $NUEVOS nuevos dominios"
        fi
    fi
    echo ""

    # 6. CREAR ALIAS Y WRAPPERS
    echo "🔧 6. Configurando accesos..."
    
    # Crear script wrapper para evitar ejecución como root
    cat > /usr/local/bin/code-safe << 'EOF'
#!/bin/bash
# Wrapper seguro para VS Code - evita ejecución como root
if [ "$EUID" -eq 0 ]; then
    echo "No ejecutes VS Code como root"
    echo "   Sal de root con: exit"
    echo "   Luego ejecuta: code"
    exit 1
else
    /usr/bin/code "$@"
fi
EOF
    chmod +x /usr/local/bin/code-safe
    
    # Crear mensaje de bienvenida
    if [ ! -f "$REAL_HOME/.vscode/welcome-message" ]; then
        run_as_user tee "$REAL_HOME/.vscode/welcome-message" > /dev/null << 'EOF'
¡VS Code configurado exitosamente!
Extensiones instaladas:
- Live Server
- Indent-rainbow
- HTML CSS Support
- Prettier
- ESLint
- Material Icon Theme
- GitHub Copilot Chat

Telemetría deshabilitada
EOF
    fi
    
    echo "Wrapper 'code-safe' creado"
    echo ""

    # RESUMEN FINAL
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "CONFIGURACIÓN COMPLETADA"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Usuario configurado: $REAL_USER"
    echo "Directorio home: $REAL_HOME"
    echo "Telemetría: DESHABILITADA (dominios bloqueados en /etc/hosts)"
    echo "Idioma: ESPAÑOL"
    echo "Extensiones: ${#EXTENSIONES[@]} totales ($existentes existentes, $nuevas nuevas)"
    echo ""
    echo "🚀 Para ejecutar VS Code:"
    echo "   1. Sal de root: exit"
    echo "   2. Ejecuta: code"
    echo ""
    echo "   O usa directamente: code-safe (evita ejecución como root)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# INSTALACIÓN COMPLETA
instalacion_completa() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "INSTALACIÓN COMPLETA DE VS CODE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Paso 1: Eliminar bloqueos
    elimina_bloqueos
    
    # Paso 2: Convertir HTTP a HTTPS
    echo ""
    http_a_https
    
    # Paso 3: Instalar VS Code
    echo ""
    instalar_vscode
    
    # Paso 4: Configurar VS Code
    configurar_vscode
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " INSTALACIÓN COMPLETADA EXITOSAMENTE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# EJECUTAR INSTALACIÓN
instalacion_completa


