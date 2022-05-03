# Operations-based workflow management

customers_dir() {
    echo "$DEVOPS_ROOT"/customer/.
}

function kcontext() {
    local noCd context
    @ARGS
        # The directory to swap to
        +d | --no-cd ) noCd="true"
            shift
            ;;
        -c | --context ) local context="$2"
            shift
            shift
    @ENDARGS

    customer="$1"
    namespace="$2"

    [ -z "$customer" ] && { echo "Usage: kcontext customer [namespace]"; return 1; }

    customer="$(customer_id "$customer" || echo "$customer")"

    if [ "$noCd" != true ]; then
        cd "$(customers_dir)/$customer"/*/namespaces/..
    fi
    kubectl config use-context ${context:-$customer}

    if [ -n "$namespace" ]; then
        kubectl config set-context --current --namespace $namespace
    fi
}
complete -W "$(ls -x "$(customers_dir)")" kcontext

function tcontext() {

    local customer customerDir
    customer="$(customer_id "$1")"
    [ $? -ne 0 ] && return 1
    customerDir="$(customers_dir)/$customer"

    if [ -d "$customerDir/aws" ]; then
        cd "$customerDir/aws"

    elif [ -d "$customerDir/azure" ]; then
        cd "$customerDir/azure"

    else
        # in the customer directory, cd to the first directory with terraform files
        cd "$(find "$customerDir" -name '*.tf' -printf '%h\n' -quit)"
    fi

    export AWS_PROFILE="$customer"
}

complete -W "$(ls -x "$(customers_dir)")" tcontext


