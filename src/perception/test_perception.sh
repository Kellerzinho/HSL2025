#!/bin/bash

# Script simplificado para testar o sistema de percepção da RoboIME
# Este script torna mais fácil testar diferentes configurações do sistema de percepção

# Cores para mensagens
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Funções
function print_header() {
    echo -e "\n${BLUE}============================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================================${NC}\n"
}

function print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

function print_error() {
    echo -e "${RED}✗ $1${NC}"
}

function print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Verificar se o script está sendo executado na raiz do workspace
SCRIPT_DIR=$(dirname "$0")
WORKSPACE_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)

if [[ "$PWD" != "$WORKSPACE_DIR" ]]; then
    print_info "Mudando para o diretório raiz do workspace: $WORKSPACE_DIR"
    cd "$WORKSPACE_DIR"
fi

# Verificar instalação do ROS 2
print_header "Verificando ambiente"

if ! command -v ros2 &> /dev/null; then
    print_error "ROS 2 não encontrado. Certifique-se de que o ROS 2 está instalado e configurado."
    exit 1
fi
print_success "ROS 2 encontrado."

# Verificar workspace
if [ ! -f "./install/setup.bash" ]; then
    print_error "Arquivo setup.bash não encontrado. Execute 'colcon build' primeiro."
    exit 1
fi
print_success "Workspace encontrado."

# Verificar pacote de percepção
if [ ! -d "./src/perception" ]; then
    print_error "Pacote 'perception' não encontrado."
    exit 1
fi
print_success "Pacote 'perception' encontrado."

# Verificar se o pacote foi construído
if [ ! -d "./install/perception" ]; then
    print_error "O pacote 'perception' não foi construído. Execute 'colcon build --packages-select perception'."
    exit 1
fi
print_success "Pacote 'perception' construído."

# Configurar ambiente
print_info "Configurando ambiente ROS 2..."
source ./install/setup.bash

# Adicionar caminho das bibliotecas Python do sistema ao PYTHONPATH
print_info "Configurando caminhos para bibliotecas Python..."
export PYTHONPATH="/usr/local/lib/python3.6/dist-packages:$PYTHONPATH"
print_success "PYTHONPATH configurado: $PYTHONPATH"

# Verificar dependências
print_header "Verificando dependências"

# Verificar TensorFlow
echo "Verificando TensorFlow..."
if python3 -c "import sys; print('Python Path:', sys.path); import tensorflow as tf; print(f'TensorFlow versão: {tf.__version__}')" 2>/dev/null; then
    print_success "TensorFlow está funcionando."
    # Verificar GPU no TensorFlow
    if python3 -c "import tensorflow as tf; print(f'GPU disponível: {len(tf.config.list_physical_devices(\"GPU\")) > 0}')" 2>/dev/null; then
        print_success "GPU disponível para TensorFlow."
    else
        print_info "GPU não disponível para TensorFlow. O sistema funcionará mais lento."
    fi
else
    print_error "TensorFlow não encontrado ou com erro. O detector YOEO não funcionará."
fi

# Verificar OpenCV
echo "Verificando OpenCV..."
if python3 -c "import cv2; print(f'OpenCV versão: {cv2.__version__}')" 2>/dev/null; then
    print_success "OpenCV está funcionando."
else
    print_error "OpenCV não encontrado ou com erro. Os detectores tradicionais não funcionarão."
fi

# Verificar se o modelo YOEO existe
echo "Verificando modelo YOEO..."
MODEL_PATH="./src/perception/resources/models/yoeo_model.h5"
if [ -f "$MODEL_PATH" ]; then
    print_success "Modelo YOEO encontrado em $MODEL_PATH"
else
    print_error "Modelo YOEO não encontrado em $MODEL_PATH"
    # Verificar diretório alternativo
    ALT_MODEL_PATH="./install/perception/share/perception/resources/models/yoeo_model.h5"
    if [ -f "$ALT_MODEL_PATH" ]; then
        print_success "Modelo YOEO encontrado em $ALT_MODEL_PATH"
    else
        print_info "O diretório de modelos será criado se não existir"
        mkdir -p "$(dirname "$MODEL_PATH")"
    fi
fi

# Menu de testes
while true; do
    print_header "MENU DE TESTES DO SISTEMA DE PERCEPÇÃO"
    echo "1. Iniciar sistema completo (YOEO + detectores tradicionais)"
    echo "2. Iniciar apenas detector YOEO"
    echo "3. Iniciar apenas detectores tradicionais"
    echo "4. Testar detecção de bola (YOEO)"
    echo "5. Testar detecção de bola (Tradicional)"
    echo "6. Testar detecção de campo (Tradicional)"
    echo "7. Testar com câmera USB"
    echo "8. Testar com câmera CSI (Jetson)"
    echo "9. Executar todos os testes sequencialmente"
    echo "0. Sair"
    
    read -p "Escolha uma opção: " option
    
    case $option in
        1)
            print_header "Iniciando sistema completo (unificado)"
            print_info "Pressione Ctrl+C para encerrar."
            PYTHONPATH="/usr/local/lib/python3.6/dist-packages:$PYTHONPATH" ros2 launch perception perception.launch.py mode:=unified
            ;;
        2)
            print_header "Iniciando apenas detector YOEO"
            print_info "Pressione Ctrl+C para encerrar."
            PYTHONPATH="/usr/local/lib/python3.6/dist-packages:$PYTHONPATH" ros2 launch perception perception.launch.py mode:=yoeo
            ;;
        3)
            print_header "Iniciando apenas detectores tradicionais"
            print_info "Pressione Ctrl+C para encerrar."
            PYTHONPATH="/usr/local/lib/python3.6/dist-packages:$PYTHONPATH" ros2 launch perception perception.launch.py mode:=traditional
            ;;
        4)
            print_header "Testando detecção de bola (YOEO)"
            print_info "Será executado por 10 segundos."
            PYTHONPATH="/usr/local/lib/python3.6/dist-packages:$PYTHONPATH" timeout 10 ros2 launch perception perception.launch.py mode:=yoeo detector_ball:=yoeo
            ;;
        5)
            print_header "Testando detecção de bola (Tradicional)"
            print_info "Será executado por 10 segundos."
            PYTHONPATH="/usr/local/lib/python3.6/dist-packages:$PYTHONPATH" timeout 10 ros2 launch perception perception.launch.py mode:=traditional detector_ball:=traditional
            ;;
        6)
            print_header "Testando detecção de campo (Tradicional)"
            print_info "Será executado por 10 segundos."
            PYTHONPATH="/usr/local/lib/python3.6/dist-packages:$PYTHONPATH" timeout 10 ros2 launch perception perception.launch.py mode:=traditional detector_field:=traditional
            ;;
        7)
            print_header "Testando com câmera USB"
            print_info "Pressione Ctrl+C para encerrar."
            PYTHONPATH="/usr/local/lib/python3.6/dist-packages:$PYTHONPATH" ros2 launch perception perception.launch.py camera_src:=usb
            ;;
        8)
            print_header "Testando com câmera CSI (Jetson)"
            print_info "Pressione Ctrl+C para encerrar."
            PYTHONPATH="/usr/local/lib/python3.6/dist-packages:$PYTHONPATH" ros2 launch perception perception.launch.py camera_src:=csi
            ;;
        9)
            print_header "Executando todos os testes sequencialmente"
            
            print_info "Teste 1: Sistema unificado (5 segundos)"
            PYTHONPATH="/usr/local/lib/python3.6/dist-packages:$PYTHONPATH" timeout 5 ros2 launch perception perception.launch.py mode:=unified
            
            print_info "Teste 2: Apenas YOEO (5 segundos)"
            PYTHONPATH="/usr/local/lib/python3.6/dist-packages:$PYTHONPATH" timeout 5 ros2 launch perception perception.launch.py mode:=yoeo
            
            print_info "Teste 3: Apenas tradicional (5 segundos)"
            PYTHONPATH="/usr/local/lib/python3.6/dist-packages:$PYTHONPATH" timeout 5 ros2 launch perception perception.launch.py mode:=traditional
            
            print_info "Teste 4: Detecção de bola YOEO (5 segundos)"
            PYTHONPATH="/usr/local/lib/python3.6/dist-packages:$PYTHONPATH" timeout 5 ros2 launch perception perception.launch.py mode:=yoeo detector_ball:=yoeo
            
            print_info "Teste 5: Detecção de bola tradicional (5 segundos)"
            PYTHONPATH="/usr/local/lib/python3.6/dist-packages:$PYTHONPATH" timeout 5 ros2 launch perception perception.launch.py mode:=traditional detector_ball:=traditional
            
            print_success "Testes concluídos!"
            ;;
        0)
            print_info "Saindo..."
            exit 0
            ;;
        *)
            print_error "Opção inválida!"
            ;;
    esac
done 