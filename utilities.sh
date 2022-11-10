
install_mirgecom() {

    MIRGE_BRANCH="main"
    MIRGE_FORK="illinois-ceesd"
    MIRGE_INSTALL="emirge"
    MIRGE_ENV_NAME="ceesd.mirgecom.env"
    OVERWRITE=false

    NONOPT_ARGS=()
    while [[ $# -gt 0 ]]; do
        case $1 in
            -b|--branch)
                MIRGE_BRANCH="$2"
                shift
                shift
                ;;
            -f|--fork)
                MIRGE_FORK="$2"
                shift
                shift
                ;;
            -i|--install)
                MIRGE_INSTALL="$2"
                shift 
                shift
                ;;
            -e|--env-name)
                MIRGE_ENV_NAME="$2"
                shift
                shift
                ;;
            --overwrite)
                OVERWRITE=true
                shift
                ;;
            -*|--*)
                echo "install_mirgecom: Unknown option $1"
                exit 1
                ;;
            *)
                NONOPT_ARGS+=("$1")
                shift
                ;;
        esac
    done

    set -- "${NONOPT_ARGS[@]}" # restore positional parameters

    echo "Installing http//github.com/${MIRGE_FORK}/mirgecom@${MIRGE_BRANCH} in ${MIRGE_INSTALL}."
    echo "- Conda env name = $MIRGE_ENV_NAME."
    if [[ "$OVERWRITE" = true ]]; then
        if [[ -d "${MIRGE_INSTALL}" ]]; then
            echo "- Overwriting ${MIRGE_INSTALL}."
            mv -f "${MIRGE_INSTALL}" "${MIRGE_INSTALL}.old"
            rm -rf "${MIRGE_INSTALL}.old" &
        fi
    fi
    # if [[ -n $1 ]]; then
    #     echo "Remaining arg: $1"
    # fi   
    # -- Install conda env, dependencies and MIRGE-Com via *emirge*
    # --- remove old run if it exists

    # --- grab emirge and install MIRGE-Com 
    # printf "> git clone https://github.com/illinois-ceesd/emirge.git ${MIRGE_INSTALL}\n"
    set -x
    git clone https://github.com/illinois-ceesd/emirge.git ${MIRGE_INSTALL}
    set +x
    cd ${MIRGE_INSTALL}
    # printf "> ./install.sh --fork=${MIRGE_FORK} --branch=${MIRGE_BRANCH} --env-name=${MIRGE_ENV_NAME}\n"
    set -x
    ./install.sh --fork=${MIRGE_FORK} --branch=${MIRGE_BRANCH} --env-name=${MIRGE_ENV_NAME}
    return_code=$?
    set +x

    cd ../
    export EMIRGE_HOME=${MIRGE_INSTALL}
    export MIRGECOM_HOME=${EMIRGE_HOME}/mirgecom
    return $return_code
}


install_mirgecom_driver() {

    DRIVER_NAME=""
    MIRGE_BRANCH="main"
    MIRGE_FORK="illinois-ceesd"
    OVERWRITE=false

    NONOPT_ARGS=()
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
                DRIVER_NAME="$2"
                shift
                shift
                ;;
            -b|--branch)
                MIRGE_BRANCH="$2"
                shift
                shift
                ;;
            -f|--fork)
                MIRGE_FORK="$2"
                shift
                shift
                ;;
            -i|--install)
                MIRGE_INSTALL="$2"
                shift 
                shift
                ;;
            -e|--env-name)
                MIRGE_ENV_NAME="$2"
                shift
                shift
                ;;
            --overwrite)
                OVERWRITE=true
                shift
                ;;
            -*|--*)
                echo "install_mirgecom: Unknown option $1"
                exit 1
                ;;
            *)
                NONOPT_ARGS+=("$1")
                shift
                ;;
        esac
    done

    set -- "${NONOPT_ARGS[@]}" # restore positional parameters

    if [[ -z "${DRIVER_NAME}" ]]; then
        echo "install_mirgecom_driver: Driver name required -n <driver name>."
        return 1
    fi
    MIRGE_INSTALL=${MIRGE_INSTALL:-"${DRIVER_NAME}"}
    echo "Installing http//github.com/${MIRGE_FORK}/${DRIVER_NAME}@${MIRGE_BRANCH} in ${MIRGE_INSTALL}."
    if [[ "$OVERWRITE" = true ]]; then
        if [[ -d "${MIRGE_INSTALL}" ]]; then
            echo "- Overwriting ${MIRGE_INSTALL}."
            mv -f "${MIRGE_INSTALL}" "${MIRGE_INSTALL}.old"
            rm -rf "${MIRGE_INSTALL}.old" &
        fi
    fi
    # if [[ -n $1 ]]; then
    #     echo "Remaining arg: $1"
    # fi   
    # -- Install conda env, dependencies and MIRGE-Com via *emirge*
    # --- remove old run if it exists

    # --- grab emirge and install MIRGE-Com 
    # printf "> git clone https://github.com/illinois-ceesd/emirge.git ${MIRGE_INSTALL}\n"
    set -x
    git clone https://github.com/${MIRGE_FORK}/${DRIVER_NAME} ${MIRGE_INSTALL}
    return_code=$?
    set +x
    return $return_code
}
