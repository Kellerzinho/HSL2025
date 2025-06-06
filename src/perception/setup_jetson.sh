#!/bin/bash
# Script para configurar o ambiente de percepção na Jetson Nano
# Este script instala as dependências necessárias e configura o ambiente

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

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then
    print_error "Este script precisa ser executado como root (use sudo)."
    exit 1
fi

# Verificar se está sendo executado em uma Jetson
if ! grep -q "NVIDIA Jetson" /proc/device-tree/model 2>/dev/null; then
    print_info "Não foi detectada uma Jetson Nano. Este script é otimizado para Jetson."
    read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        print_info "Abortando instalação."
        exit 0
    fi
fi

# Verificar se o ROS 2 está instalado
print_header "Verificando ROS 2"
if ! command -v ros2 &> /dev/null; then
    print_error "ROS 2 não encontrado. Instale o ROS 2 antes de continuar."
    print_info "Você pode instalar usando o Dockerfile no diretório docker/"
    exit 1
fi
print_success "ROS 2 encontrado."

# Instalar dependências
print_header "Instalando dependências"

print_info "Atualizando lista de pacotes..."
apt-get update

print_info "Instalando pacotes de sistema necessários..."
apt-get install -y --no-install-recommends \
    python3-pip \
    python3-numpy \
    python3-opencv \
    python3-yaml \
    libopencv-dev \
    gstreamer1.0-tools \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    git

print_info "Verificando dependências do Python..."
pip3 install -U pip
pip3 install -U \
    matplotlib \
    numpy \
    pyyaml \
    rospkg \
    empy \
    torch==1.10.0 \
    torchvision==0.11.0 \
    tqdm \
    opencv-python

# Verificar TensorFlow e instalar se necessário
if ! python3 -c "import tensorflow" &> /dev/null; then
    print_info "TensorFlow não encontrado. Instalando versão compatível com Jetson..."
    
    # Instalar dependências do TensorFlow
    apt-get install -y libhdf5-serial-dev hdf5-tools
    
    # Instalar TensorFlow versão compatível com a Jetson
    pip3 install -U --no-deps \
        numpy==1.19.4 \
        future==0.18.2 \
        mock==3.0.5 \
        keras_preprocessing==1.1.2 \
        keras_applications==1.0.8 \
        gast==0.4.0 \
        protobuf==3.19.4 \
        absl-py==0.11.0 \
        h5py==3.1.0 \
        tensorboard==2.4.1 \
        tensorflow-estimator==2.4.0
    
    # Instalar TensorFlow para Jetson
    pip3 install --pre --extra-index-url https://developer.download.nvidia.com/compute/redist/jp/v46 tensorflow==2.4.0+nv21.5
    
    # Verificar instalação
    if python3 -c "import tensorflow as tf; print(tf.__version__)" &> /dev/null; then
        print_success "TensorFlow instalado com sucesso."
    else
        print_error "Falha ao instalar TensorFlow."
    fi
else
    print_success "TensorFlow já está instalado."
fi

# Instalar YOLOv5 original (não Ultralytics)
print_header "Instalando YOLOv5 original"

YOLOV5_DIR="/opt/yolov5"

# Remover diretório anterior se existir
if [ -d "$YOLOV5_DIR" ]; then
    print_info "Removendo instalação anterior do YOLOv5..."
    rm -rf "$YOLOV5_DIR"
fi

# Clonar o repositório YOLOv5 (versão compatível com Python 3.6.9)
print_info "Clonando YOLOv5 versão 5.0 (compatível com Python 3.6.9)..."
git clone -b v5.0 https://github.com/ultralytics/yolov5.git "$YOLOV5_DIR"

if [ $? -eq 0 ]; then
    print_success "YOLOv5 clonado com sucesso em $YOLOV5_DIR"
    
    # Configurar permissões
    chown -R $SUDO_USER:$SUDO_USER "$YOLOV5_DIR"
    chmod -R 755 "$YOLOV5_DIR"
    
    # Instalar dependências do YOLOv5
    print_info "Instalando dependências do YOLOv5..."
    cd "$YOLOV5_DIR"
    pip3 install -r requirements.txt
    
    # Baixar pesos pré-treinados
    print_info "Baixando pesos pré-treinados..."
    # Usar curl em vez de wget e salvar diretamente no diretório
    curl -L https://github.com/ultralytics/yolov5/releases/download/v5.0/yolov5s.pt -o "$YOLOV5_DIR/yolov5s.pt"
    
    if [ -f "$YOLOV5_DIR/yolov5s.pt" ]; then
        print_success "Pesos pré-treinados baixados com sucesso."
    else
        print_error "Falha ao baixar pesos pré-treinados. Você pode baixá-los manualmente em:"
        print_info "https://github.com/ultralytics/yolov5/releases/download/v5.0/yolov5s.pt"
    fi
    
    # Adicionar YOLOV5_PATH ao ambiente
    ENV_FILE="/home/$SUDO_USER/.bashrc"
    if ! grep -q "YOLOV5_PATH" "$ENV_FILE"; then
        echo "# Configuração do YOLOv5" >> "$ENV_FILE"
        echo "export YOLOV5_PATH=\"$YOLOV5_DIR\"" >> "$ENV_FILE"
        print_success "YOLOV5_PATH adicionado ao .bashrc"
    else
        print_success "YOLOV5_PATH já configurado."
    fi
    
    # Adicionar a variável de ambiente também para o ambiente atual
    export YOLOV5_PATH="$YOLOV5_DIR"
    
else
    print_error "Falha ao clonar o repositório YOLOv5."
fi

# Configurar diretórios para os modelos
print_header "Configurando diretórios de recursos"

WORKSPACE_DIR=$(cd "$(dirname "$0")/../.." && pwd)
PERCEPTION_DIR="$WORKSPACE_DIR/src/perception"
RESOURCES_DIR="$PERCEPTION_DIR/resources"
MODELS_DIR="$RESOURCES_DIR/models"

print_info "Criando diretórios de recursos..."
mkdir -p "$MODELS_DIR"
print_success "Diretórios criados: $MODELS_DIR"

# Verificar se os pesos pré-treinados estão no YOLOv5_DIR e copiá-los para MODELS_DIR
if [ -f "$YOLOV5_DIR/yolov5s.pt" ]; then
    print_info "Copiando pesos pré-treinados para o diretório de modelos..."
    cp "$YOLOV5_DIR/yolov5s.pt" "$MODELS_DIR/yolov5s.pt"
    print_success "Pesos copiados para $MODELS_DIR/yolov5s.pt"
fi

# Configurar permissões e grupos
print_header "Configurando permissões"

# Adicionar usuário ao grupo video para acesso à câmera
if id -nG | grep -qw "video"; then
    print_success "Usuário já pertence ao grupo video."
else
    usermod -a -G video $SUDO_USER
    print_success "Usuário adicionado ao grupo video."
fi

# Definir permissões para diretórios de recursos
chown -R $SUDO_USER:$SUDO_USER "$RESOURCES_DIR"
chmod -R 755 "$RESOURCES_DIR"
print_success "Permissões configuradas para $RESOURCES_DIR"

# Configurar variáveis de ambiente
print_header "Configurando variáveis de ambiente"

ENV_FILE="/home/$SUDO_USER/.bashrc"
if ! grep -q "PERCEPTION_RESOURCES_DIR" "$ENV_FILE"; then
    echo "" >> "$ENV_FILE"
    echo "# Configurações de ambiente para percepção" >> "$ENV_FILE"
    echo "export PERCEPTION_RESOURCES_DIR=\"$RESOURCES_DIR\"" >> "$ENV_FILE"
    echo "export PERCEPTION_MODELS_DIR=\"$MODELS_DIR\"" >> "$ENV_FILE"
    print_success "Variáveis de ambiente adicionadas ao .bashrc"
else
    print_success "Variáveis de ambiente já configuradas."
fi

# Adicionar source do workspace
if ! grep -q "source $WORKSPACE_DIR/install/setup.bash" "$ENV_FILE"; then
    echo "source $WORKSPACE_DIR/install/setup.bash" >> "$ENV_FILE"
    print_success "Source do workspace adicionado ao .bashrc"
else
    print_success "Source do workspace já configurado."
fi

# Compilar o workspace
print_header "Compilando o workspace"

print_info "Alterando para o diretório do workspace: $WORKSPACE_DIR"
cd "$WORKSPACE_DIR"

# Executar como o usuário original, não como root
print_info "Compilando o pacote de percepção..."
su - $SUDO_USER -c "cd $WORKSPACE_DIR && colcon build --packages-select perception"

if [ $? -eq 0 ]; then
    print_success "Pacote de percepção compilado com sucesso!"
else
    print_error "Falha ao compilar o pacote de percepção."
fi

print_header "Configuração concluída!"
print_info "Ambiente YOLOv5 configurado em: $YOLOV5_DIR"
print_info "Para testar o sistema de percepção, execute:"
print_info "cd $WORKSPACE_DIR && ./src/perception/test_perception.sh"
print_info "Nota: Pode ser necessário reiniciar o terminal para aplicar todas as configurações."
print_info "Após reiniciar, você pode executar 'ros2 launch perception perception.launch.py' para iniciar o sistema." 