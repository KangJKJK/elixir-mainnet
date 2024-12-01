#!/bin/bash

# 색깔 변수 정의
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[36m'
NC='\033[0m' # No Color

echo -e "${GREEN}Elixir-메인넷 노드 설치 또는 업데이트를 선택하세요.${NC}"
echo -e "${BOLD}${YELLOW}1. 엘릭서 메인넷 노드 새로 설치${NC}"
echo -e "${BOLD}${YELLOW}2. 엘릭서 메인넷 노드 업데이트${NC}"
read -p "선택 (1 또는 2): " choice

case "$choice" in
    1)
    echo -e "${GREEN}Elixir-메인넷 노드 설치를 시작합니다.${NC}"

    command_exists() {
        command -v "$1" &> /dev/null
    }

    echo ""

    # NVM 설치
    echo -e "${YELLOW}NVM을 설치하는 중입니다...${NC}"
    apt install npm -y
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash

    # NVM 설정을 현재 세션에 적용
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

    # .bashrc 또는 .bash_profile에 NVM 설정 추가
    echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> ~/.bashrc

    # NVM을 사용하여 LTS Node.js 설치
    nvm install --lts
    nvm use --lts

    # 설치된 Node.js 버전 확인
    node -v

    echo -e "${BOLD}${CYAN}ethers 패키지 설치 확인 중...${NC}"
    if ! npm list ethers &> /dev/null; then
        echo -e "${RED}ethers 패키지가 없습니다. ethers 패키지를 설치하는 중입니다...${NC}"
        npm install ethers
        echo -e "${GREEN}ethers 패키지가 성공적으로 설치되었습니다.${NC}"
    else
        echo -e "${GREEN}ethers 패키지가 이미 설치되어 있습니다.${NC}"
    fi

    echo -e "${BOLD}${CYAN}Docker 설치 확인 중...${NC}"
    if ! command_exists docker; then
        echo -e "${RED}Docker가 설치되어 있지 않습니다. Docker를 설치하는 중입니다...${NC}"
        sudo apt update && sudo apt install -y curl net-tools
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        echo -e "${GREEN}Docker가 성공적으로 설치되었습니다.${NC}"
    else
        echo -e "${GREEN}Docker가 이미 설치되어 있습니다.${NC}"
    fi

    # validator_wallet.txt 파일 존재 여부 및 내용 확인
    VALID_FILE=false
    if [[ -f validator_wallet.txt ]]; then
        # 파일이 존재할 경우, 개인 키 및 주소를 읽어옴
        PRIVATE_KEY=$(grep "Private Key:" validator_wallet.txt | awk -F': ' '{print $2}' | sed 's/^0x//')
        VALIDATOR_ADDRESS=$(grep "Address:" validator_wallet.txt | awk -F': ' '{print $2}')
        
        # 파일 내용이 유효한지 확인
        if [[ ! -z "$PRIVATE_KEY" && ! -z "$VALIDATOR_ADDRESS" ]]; then
            VALID_FILE=true
            echo -e "${GREEN}기존 validator_wallet.txt 파일에서 정보를 불러왔습니다.${NC}"
            echo -e "${YELLOW}검증자 주소: ${NC}${VALIDATOR_ADDRESS}"
            echo -e "${YELLOW}프라이빗 키: ${NC}${PRIVATE_KEY}"
            echo ""
            read -p "이 정보가 맞습니까? (y/n): " confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                VALID_FILE=false
                echo -e "${RED}저장된 정보를 사용하지 않습니다. 새로운 정보를 입력해주세요.${NC}"
            fi
        fi
    fi

    # 파일이 없거나 유효하지 않은 경우 새로 생성
    if [[ "$VALID_FILE" = false ]]; then
        echo -e "${RED}유효한 validator_wallet.txt 파일이 없습니다. 새로 생성합니다.${NC}"
        
        # 검증자 지갑의 프라이빗 키와 주소를 입력받아 validator_wallet.txt 파일 생성
        read -p "검증자 지갑의 프라이빗 키를 입력하세요(0x포함하지않음): " PRIVATE_KEY
        read -p "검증자 지갑 주소를 입력하세요: " VALIDATOR_ADDRESS

        # validator_wallet.txt 파일에 정보 저장
        echo "Private Key: $PRIVATE_KEY" > validator_wallet.txt
        echo "Address: $VALIDATOR_ADDRESS" >> validator_wallet.txt
    fi

    ENV_FILE="validator.env"
    
    if [[ -f "$ENV_FILE" ]]; then
        CURRENT_NAME=$(grep "STRATEGY_EXECUTOR_DISPLAY_NAME" $ENV_FILE | cut -d'=' -f2)
        CURRENT_BENEFICIARY=$(grep "STRATEGY_EXECUTOR_BENEFICIARY" $ENV_FILE | cut -d'=' -f2)
        CURRENT_KEY=$(grep "SIGNER_PRIVATE_KEY" $ENV_FILE | cut -d'=' -f2)
        
        echo -e "${YELLOW}현재 설정:${NC}"
        echo -e "검증자 이름: ${CYAN}$CURRENT_NAME${NC}"
        echo -e "보상 지갑 주소: ${CYAN}$CURRENT_BENEFICIARY${NC}"
        echo -e "프라이빗 키: ${CYAN}$CURRENT_KEY${NC}"
        
        read -p "설정을 변경하시겠습니까? (y/n): " change_settings
        if [[ "$change_settings" == "y" || "$change_settings" == "Y" ]]; then
            IP_ADDRESS=$(curl -s ifconfig.me)
            echo "STRATEGY_EXECUTOR_IP_ADDRESS=$IP_ADDRESS" >> $ENV_FILE
            
            read -p "검증자 이름을 입력하세요 : " DISPLAY_NAME
            echo "STRATEGY_EXECUTOR_DISPLAY_NAME=$DISPLAY_NAME" >> $ENV_FILE

            read -p "검증자 보상을 받을 EVM지갑 주소를 입력하세요: " BENEFICIARY
            echo "STRATEGY_EXECUTOR_BENEFICIARY=$BENEFICIARY" >> $ENV_FILE
            
            PRIVATE_KEY=$(grep "Private Key:" validator_wallet.txt | awk -F': ' '{print $2}' | sed 's/^0x//')
            echo "SIGNER_PRIVATE_KEY=$PRIVATE_KEY" >> $ENV_FILE
        fi
    else
        IP_ADDRESS=$(curl -s ifconfig.me)
        echo "STRATEGY_EXECUTOR_IP_ADDRESS=$IP_ADDRESS" >> $ENV_FILE
        
        read -p "검증자 이름을 입력하세요 : " DISPLAY_NAME
        echo "STRATEGY_EXECUTOR_DISPLAY_NAME=$DISPLAY_NAME" >> $ENV_FILE

        read -p "검증자 보상을 받을 EVM지갑 주소를 입력하세요: " BENEFICIARY
        echo "STRATEGY_EXECUTOR_BENEFICIARY=$BENEFICIARY" >> $ENV_FILE
        
        PRIVATE_KEY=$(grep "Private Key:" validator_wallet.txt | awk -F': ' '{print $2}' | sed 's/^0x//')
        echo "SIGNER_PRIVATE_KEY=$PRIVATE_KEY" >> $ENV_FILE
    fi

    echo ""
    echo -e "${BOLD}${CYAN}${ENV_FILE} 파일이 다음 내용으로 생성되었습니다:${NC}"
    cat $ENV_FILE
    echo ""

    if [[ "$response" =~ ^[yY]$ ]]; then
        echo -e "${BOLD}${CYAN}Elixir Protocol Validator 이미지 생성 중...${NC}"
        docker pull elixirprotocol/validator
    else
        echo -e "${RED}작업이 완료되지 않았습니다. 스크립트를 종료합니다.${NC}"
        exit 1
    fi

    # 현재 사용 중인 포트 확인
    used_ports=$(netstat -tuln | awk '{print $4}' | grep -o '[0-9]*$' | sort -u)

    # 각 포트에 대해 ufw allow 실행
    for port in $used_ports; do
        echo -e "${GREEN}포트 ${port}을(를) 허용합니다.${NC}"
        sudo ufw allow $port
    done

    echo -e "${GREEN}모든 사용 중인 포트가 허용되었습니다.${NC}"

    echo -e "${BOLD}${CYAN}Docker 실행 중...${NC}"
    docker run -d --env-file validator.env --name elixir -p 17690:17690 --restart unless-stopped elixirprotocol/validator
    echo ""

    # 현재 사용 중인 포트 확인 및 허용
    echo -e "${GREEN}현재 사용 중인 포트를 확인합니다...${NC}"
    
    # TCP 포트 확인 및 허용
    echo -e "${YELLOW}TCP 포트 확인 및 허용 중...${NC}"
    sudo ss -tlpn | grep LISTEN | awk '{print $4}' | cut -d':' -f2 | while read port; do
        echo -e "TCP 포트 ${GREEN}$port${NC} 허용"
        sudo ufw allow $port/tcp
    done
    
    # UDP 포트 확인 및 허용
    echo -e "${YELLOW}UDP 포트 확인 및 허용 중...${NC}"
    sudo ss -ulpn | grep LISTEN | awk '{print $4}' | cut -d':' -f2 | while read port; do
        echo -e "UDP 포트 ${GREEN}$port${NC} 허용"
        sudo ufw allow $port/udp
    done

    echo -e "${GREEN}모든 작업이 완료되었습니다. 컨트롤+A+D로 스크린을 종료해주세요.${NC}"
    echo -e "${GREEN}대시보드사이트: https://www.elixir.xyz/validators${NC}"
    echo -e "${GREEN}스크립트 작성자: https://t.me/kjkresearch${NC}"
    ;;

    2)
    echo -e "${GREEN}엘릭서 노드 업데이트를 시작합니다.${NC}"
    docker stop elixir
    docker kill elixir
    docker rm elixir
    docker pull elixirprotocol/validator
    echo -e "${GREEN}대시보드사이트: https://www.elixir.xyz/validators${NC}"
    echo -e "${GREEN}스크립트 작성자: https://t.me/kjkresearch${NC}"
    ;;

    *)
    echo -e "${RED}잘못된 선택입니다. 스크립트를 종료합니다.${NC}"
    exit 1
    ;;
esac
