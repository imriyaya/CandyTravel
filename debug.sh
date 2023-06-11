#!/bin/bash

mkdir debug
cd debug

if [ -z $PAPERMC_VERSION ]; then
    PAPERMC_VERSION="1.19.2"
fi
if [ -z $PAPERMC_JAR_NAME ]; then
    PAPERMC_JAR_NAME="paperclip.jar"
fi
if [ -z $PAPERMC_START_MEMORY ]; then
    PAPERMC_START_MEMORY="1G"
fi
if [ -z $PAPERMC_MAX_MEMORY ]; then
    PAPERMC_MAX_MEMORY="1G"
fi
if [ -z $PAPERMC_UPDATE_SECONDS ]; then
    PAPERMC_UPDATE_SECONDS=86400
fi

trap shutdown_message INT
function shutdown_message() {
    PAPERMC_SHUTDOWN=1
}

lastmod() {
    expr `date +%s` - `stat -c %Y $1`
}

while (( "$#" )); do
  case "$1" in
    --skip-update)
      PAPERMC_SKIP_UPDATE=1
      shift
      ;;
    --mojang-eula-agree)
      MOJANG_EULA_AGREE=1
      shift
      ;;
    --auto-restart)
      AUTO_RESTART=1
      shift
      ;;
    --version)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        PAPERMC_VERSION=$2
        shift 2
      else
        echo "ERROR: Argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    --jar-name)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        PAPERMC_JAR_NAME=$2
        shift 2
      else
        echo "ERROR: Argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    -ms|--start-memory)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        PAPERMC_START_MEMORY=$2
        shift 2
      else
        echo "ERROR: Argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    -mx|--max-memory)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        PAPERMC_MAX_MEMORY=$2
        shift 2
      else
        echo "ERROR: Argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    -*|--*=) # unsupported flags
      echo "ERROR: Unsupported flag $1" >&2
      exit 1
      ;;
    *) # preserve positional arguments
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done

eval set -- "$PARAMS"

LATEST_BUILD=$(curl -s "https://papermc.io/api/v2/projects/paper/versions/${PAPERMC_VERSION}" | jq '.builds[-1]')
LATEST_DOWNLOAD=$(curl -s "https://papermc.io/api/v2/projects/paper/versions/${PAPERMC_VERSION}/builds/${LATEST_BUILD}" | jq '.downloads.application.name' -r)

PAPERMC_DOWNLOAD_URL="https://papermc.io/api/v2/projects/paper/versions/${PAPERMC_VERSION}/builds/${LATEST_BUILD}/downloads/${LATEST_DOWNLOAD}"

function update_papermc() {
    if ! [ -f "$PAPERMC_JAR_NAME" ]; then
        echo "Downloading PaperMC ${PAPERMC_DOWNLOAD_URL} -> ${PAPERMC_JAR_NAME}..."
        echo "> curl -s -o ${PAPERMC_JAR_NAME} ${PAPERMC_DOWNLOAD_URL}"
        curl -s -o ${PAPERMC_JAR_NAME} ${PAPERMC_DOWNLOAD_URL}
    else
        if [ -z $PAPERMC_SKIP_UPDATE ]; then
            SEC_SINCE_UPDATE=$(lastmod ${PAPERMC_JAR_NAME})

            if [ "$SEC_SINCE_UPDATE" -gt "$PAPERMC_UPDATE_SECONDS" ]; then
                rm ${PAPERMC_JAR_NAME}
                echo "Updating PaperMC ${PAPERMC_DOWNLOAD_URL} -> ${PAPERMC_JAR_NAME}..."
                echo "> curl -s -o ${PAPERMC_JAR_NAME} ${PAPERMC_DOWNLOAD_URL}"
                curl -s -o ${PAPERMC_JAR_NAME} ${PAPERMC_DOWNLOAD_URL}
            else
                echo "Skipping PaperMC update, ${SEC_SINCE_UPDATE} !> ${PAPERMC_UPDATE_SECONDS}..."
            fi
        else
            echo "Skipping PaperMC update, skip flag..."
        fi
    fi

    if ! [ -z $PAPERMC_SHUTDOWN ]; then
        echo "ERROR: Download cancelled, cleaning up..."
        rm ${PAPERMC_JAR_NAME}
        exit 1
    fi
}

function start_papermc() {
    echo "> java ${PAPERMC_JAVA_ARGS} -Dcom.mojang.eula.agree=true -jar ${PAPERMC_JAR_NAME} ${PAPERMC_ARGS} ${PARAMS}"
    java -Dcom.mojang.eula.agree=true -jar ${PAPERMC_JAR_NAME} ${PAPERMC_ARGS} ${PARAMS}
}

if [ -z $AUTO_RESTART ]; then
    update_papermc

    echo "Starting PaperMC Server..."
    start_papermc
else
    while [ -z $PAPERMC_SHUTDOWN ]; do
        update_papermc

        echo "Starting PaperMC Server, Auto-Restart Enabled..."
        start_papermc
        sleep 3
    done
fi

echo "PaperMC Server Shutdown."