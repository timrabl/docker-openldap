#!/bin/sh

set -e

# Envsubst export make sure to unset later
export LDAP_RUN_DIR=${LDAP_RUN_DIR:="/run/openldap/"}
export LDAP_TLS_CA=${LDAP_TLS_CA:="/etc/openldap/tls/openldap_ca.crt"}
export LDAP_TLS_CERT=${LDAP_TLS_CERT:="/etc/openldap/tls/openldap.crt"}
export LDAP_TLS_KEY=${LDAP_TLS_KEY:="/etc/openldap/tls/openldap.key"}

# Defaults
LDAP_DATA_DIR=${LDAP_DATA_DIR} #provided by Dockerfile, reason: volume expose in Dockefile
LDAP_GROUP=${LDAP_GROUP:="ldap"}
LDAP_IPC_LISTEN="ldapi://$(echo "$LDAP_RUN_DIR/ldapi" | sed 's|/|%2F|g')"
LDAP_LISTEN_MODES=${LDAP_IPC_LISTEN_PROTOCOLS:="ldaps:///"}
LDAP_USER=${LDAP_USER:="ldap"}

# Slapd vars
SLAPD_CONFIG_DIR=${LDAP_CONFIG_DIR:="/etc/openldap/slapd.d"}
SLAPD_CONFIG_FILE_PATH=${LDAP_CONFIG_FILE_PATH:="/etc/openldap/slapd.conf"}
SLAPD_CONFIG_TEMPLATE_PATH=${LDAP_CONFIG_TEMPLATE_PATH:="/etc/openldap/slapd.subst"}
SLAPD_DEBUG=${LDAP_DEBUG:="4"}
SLAPD_SEED_DIR=${SLAPD_SEED_DIR:="/etc/openldap/seed/slapd"}

# LDAP seeder vars
LDAP_SEED_ENABLE=${LDAP_SEED_ENABLE:="false"}
LDAP_SEED_DIR=${LDAP_SEED_DIR:="/etc/openldap/seed/ldap/"}
LDAP_SEED_WAIT_TIMEOUT=${LDAP_SEED_WAIT_TIMEOUT:="3"}
LDAP_SEED_TARGET=${LDAP_SEED_TARGET:="ldaps://ldap-master"}
LDAP_SEED_DN=${LDAP_SEED_DN:="cn=Manager,$SUFFIX"}
LDAP_SEED_PW=${LDAP_SEED_PW:-$LDAP_PASSWORD}

# Vars that 'll be substituted in file via envsubst
# SINGLE QOUTES !!
_REQ_VARS='$LDAP_TLS_CA:$LDAP_TLS_CERT:$LDAP_TLS_KEY:$LDAP_DATA_DIR:$LDAP_RUN_DIR:$SUFFIX:$LDAP_PASSWORD'

# LDAP seeder section
if [[ "$LDAP_SEED_ENABLE" == "true" ]]; then
    # Internal docker connection, so we can ignore the certs
    echo "TLS_REQCERT never" >> /etc/openldap/ldap.conf

    # wait for the ldap server to start
    sleep $LDAP_SEED_WAIT_TIMEOUT

    for FILE in $(find $LDAP_SEED_DIR -type f | sort -n ); do
        grep -iq changetype $FILE && \
            MODE="ldapmodify" || \
            MODE="ldapadd"

        [[ ! -z "$LDAP_IPC_LISTEN" ]] && \
            ARGS="-x -H $LDAP_SEED_TARGET -D $LDAP_SEED_DN -w $LDAP_SEED_PW" || \
            ARGS="-Y EXTERNAL -Q -H $LDAP_IPC_LISTEN"

        case "$FILE" in
            *.subst )
                echo "[  LDAP - Seeder ] seeding substituted ldap config file: $FILE ..."
                envsubst "$_REQ_VARS" < $FILE | $MODE $ARGS 2>&1
                ;;
            *.ldif )
                echo "[  LDAP - Seeder ] seeding ldap config file: $FILE ..."
                $MODE $ARGS -f $FILE 2>&1
                ;;
            * )
                echo "[  LDAP - Seeder ] Invalid file: $FILE !"
                ;;
        esac
    done
    exit 0
fi

# Subsititue slapd.subst to slapd.conf
[[ ! -f "$SLAPD_CONFIG_FILE_PATH" ]] && \
    envsubst "$_REQ_VARS" < $SLAPD_CONFIG_TEMPLATE_PATH > $SLAPD_CONFIG_FILE_PATH || \
    echo "[ SLAPD Substitutor ] slapd.conf already exist, skipping substitution ..."

chown root:$LDAP_GROUP $SLAPD_CONFIG_FILE_PATH
chmod 640 $SLAPD_CONFIG_FILE_PATH

# "run" directory for socket, pid, etc.
[[ ! -d $LDAP_RUN_DIR ]] && \
    mkdir -p $LDAP_RUN_DIR
chown -R $LDAP_USER:$LDAP_GROUP $LDAP_RUN_DIR

# "config" dir for slap configs ( adds ability for compsoe volume )
[[ ! -d $SLAPD_CONFIG_DIR ]] && \
    mkdir -p $SLAPD_CONFIG_DIR
chown -R $LDAP_USER:$LDAP_GROUP $SLAPD_CONFIG_DIR

# "openldap-data" dir
[[ ! -d $LDAP_DATA_DIR ]] && \
    mkdir -p $LDAP_DATA_DIR
chown -R $LDAP_USER:$LDAP_GROUP $LDAP_DATA_DIR
chmod 700 $LDAP_DATA_DIR

# Apply additional slapd configs from seed directory
for FILE in $(find $SLAPD_SEED_DIR -type f | sort -n ); do
    ARGS="slapdd -f $SLAPD_CONFIG_FILE_PATH -F $SLAPD_CONFIG_DIR"
    case "$FILE" in
        *.subst )
            echo "[ SLAPD - Seeder ] seeding substituted slapd config file $FILE ..."
            envsubst "$_REQ_VARS" < $FILE | $ARGS
            ;;
        *.ldif )
            echo "[ SLAPD - Seeder ] seeding slapd config file: $LDIF ..."
            $ARGS -l $FILE
            ;;
        * )
            echo "[ SLAPD - Seeder ] Invalid file: $FILE !"
            ;;
    esac
done

unset LDAP_RUN_DIR LDAP_TLS_KEY LDAP_TLS_CERT LDAP_TLS_CA LDAP_TLS_KEY

# Service startup
exec slapd -f $SLAPD_CONFIG_FILE_PATH -F $SLAPD_CONFIG_DIR \
    -h "$LDAP_LISTEN_MODES $LDAP_IPC_LISTEN" -d $SLAPD_DEBUG \
    -u $LDAP_USER -g $LDAP_GROUP
