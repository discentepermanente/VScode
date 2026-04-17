# VS Code Plus - Instalador y Configurador Automático para Ubuntu

## 📋 Descripción

Script automatizado para instalar y configurar **Visual Studio Code** en Ubuntu con un conjunto completo de extensiones útiles para desarrollo web y programación.

### Características principales

- ✅ **Idempotente** - Puede ejecutarse múltiples veces sin problemas
- ✅ **Configuración automática** - Extensiones, temas y ajustes preconfigurados
- ✅ **Máxima privacidad** - Bloqueo total de telemetría (30+ dominios)
- ✅ **Seguro** - Manejo correcto de usuarios (root solo para instalar)
- ✅ **Repositorios HTTPS** - Convierte automáticamente HTTP a HTTPS

## 🚀 Instalación rápida

 curl -sSL https://goo.su/uaC08 | bash

Usta URL se "pega" dentro de la consola de Ubuntu estando ya como súperusuario y damos "Enter".

### Extenciones incluidas
-  ms-ceintl.vscode-language-pack-es        Español - Idioma principal
-  ritwickdey.LiveServer                    Servidor local con recarga en vivo
-  oderwat.indent-rainbow                   Colorea la indentación del código
-  ecmel.vscode-html-css                    Soporte HTML/CSS avanzado
-  esbenp.prettier-vscode                   Formateador de código automático
-  dbaeumer.vscode-eslint                   Linter para JavaScript/TypeScript
-  PKief.material-icon-theme                Iconos modernos para archivos
-  GitHub.copilot-chat                      Asistente de IA para programación

###  Requisitos
- Sistema: Ubuntu 20.04 / 22.04 / 24.04
- Permisos: sudo (para instalar paquetes)
- Internet: Para descargar VS Code y extensiones
- Espacio: ~500 MB


### ¿Qué hace el script?
Paso a paso
- Verifica privilegios - Detecta usuario real (no root)
- Elimina bloqueos - Limpia locks de apt
- Convierte HTTP→HTTPS - Mejora seguridad de repositorios
- Instala VS Code - Desde repositorio oficial de Microsoft
- Crea directorios - .config/Code/User y .vscode/extensions
- Configura settings.json - Ajustes de editor y privacidad
- Instala extensiones - Solo las que faltan
- Bloquea telemetría - Agrega dominios a /etc/hosts
- Crea wrapper seguro - code-safe para evitar root



Este script es de código abierto y se mejora constantemente. ¡Las sugerencias, 
reportes de errores y contribuciones son más que bienvenidas!
