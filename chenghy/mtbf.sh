#!/bin/bash -x

#################################################################
##       Mean Time Between Failure Test Framework for Xen
##
##              Change Log
## Ver.  Date         Author                      Description
##       2016/01/18   binx.wu@intel.com           Code review
## 1.0   2015/12/31   binx.wu@intel.com           Code freeze for version release
##       2015/12/30   binx.wu@intel.com           Add Guest status judgment to fix when pause Guest will kill it
##                                                Add log catch compare function to store different log
##       2015/12/29   binx.wu@intel.com           Add syslog etc. log catch at func_case_record_error_log
##       2015/12/09   binx.wu@intel.com           Add Result summary
##       2015/12/08   binx.wu@intel.com           Add version dump function to direct output script version
##                                                Add store_workload keyword, it also mapping with -s option, 
##                                                which save the workload STAF process
##       2015/11/13   binx.wu@intel.com           Change recover to child process
##       2015/11/12   binx.wu@intel.com           Fix the bug refer vm count is 1 to detect ip problem
##       2015/11/09   binx.wu@intel.com           Add func_tool_cmd_loop_pass to run the command in the loop
##       2015/11/06   binx.wu@intel.com           Add Command option detect which will useful in different env
##                                                fix time catch when date change will meet then problem
##       2015/11/05   binx.wu@intel.com           Update log catch function
##       2015/11/04   binx.wu@intel.com           Modify the default value refer conf: exec & exec_home
##                                                replace MAC address generate funciton
##       2015/10/29   binx.wu@intel.com           Child pid script will quit when Parent PID unexist
##                                                Add workload log record
##                                                Add run time record
##                                                Add default configure viridian=1
##       2015/10/28   binx.wu@intel.com           Add Dom0 workload script support
##                                                Fix IP detect problem with unset MAC
##       2015/10/27   binx.wu@intel.com           Add keyword value constraint for configure file
##                                                Add Display check & display empty support
##       2015/10/10   binx.wu@intel.com           Add guest os detect in mtbf_env_check
##                                                change keyword "max_vm_count" -> "vm_count"
##                                                fix FETCH_IP check problem which find in BJ network
##                                                code review for parameter, fix dom0 execute miss, add env clear
##       2015/10/08   binx.wu@intel.com           fix typo error refer func_cmd_pass to func_tool_cmd_run_pass
##       2015/09/25   binx.wu@intel.com           Initialization
##
#################################################################





#################################################################
##
## There is the var for kvmgt
## different vars include:
##qemU-img  qemu-systemx86 sm
##
#################################################################


KVM=0
XEN=1
XEN_FLAG=/var/run/xenstored.pid

if [ -f $XEN_FLAG ];then
    VMM_TYPE=$XEN
else
    VMM_TYPE=$KVM
fi


if [ $VMM_TYPE -eq $KVM ];then
    QEMU_IMG=`which qemu-img`
    QEMU_SYS=`which qemu-system-x86_64`
fi

if [ $VMM_TYPE -eq $XEN ];then
    QEMU_IMG=`which qemu-img`
    QEMU_SYS=/usr/lib/xen/bin/qemu-system-i386
fi

#################################################################
##
## Framework Script define
## paramter flag: FW
##
#################################################################
FW_HOME=`dirname $0`
FW_NAME=`basename $0`
FW_PID="$$"
FW_CASE_NAME="mtbf"
FW_CONF_FILE="/home/$FW_CASE_NAME/conf.ini"
FW_SER_URL="http://gvt-server.sh.intel.com/download/"
FW_TMP_FOLDER="/tmp/$FW_CASE_NAME"
FW_CMD_LOOP=10

#################################################################
##
## other define
##
#################################################################
# xen bridge
BRG_MULTI_SUPPORT=0
BRG_HOST=""

STAF_HOME="/usr/local/staf"
XEN_LOG_PATH="/var/log/xen/"

# ip detect
FETCH_IP=""
# Xorg detect
FETCH_XORG=1

#################################################################
##
## Time refer define
## paramter flag: TIME
##
#################################################################
TIME_FW_WAIT="6s"
TIME_XL_WAIT="5s"
TIME_STAF_WAIT="30s"
TIME_SCAN_WAIT="$TIME_STAF_WAIT"
TIME_CLEAR_WAIT="$TIME_STAF_WAIT"

#################################################################
##
## Script quit/exit status define
## paramter flag: ERR_LV
##
#################################################################
ERR_LV_PASS=0
ERR_LV_ENV=1
ERR_LV_PARA=2
ERR_LV_BLOCK=3
ERR_LV_ERR=4
ERR_LV_CHILD=5
ERR_LV_UNKNOW=6

#################################################################
##
## ENV command/file define
## paramter flag: CMD
##
#################################################################
CMD_STAF="staf"
CMD_PARSE="parse_ini"
# xen refer command
CMD_XL="xl"
CMD_XL_VMLIST="$CMD_XL vm-list"
CMD_XL_DMESG="$CMD_XL dmesg"
CMD_XL_INFO="$CMD_XL info"
CMD_XL_CREATE="$CMD_XL create"
CMD_XL_DESTROY="$CMD_XL destroy"
CMD_XL_STATUS="$CMD_XL list"
CMD_XL_DOMID="$CMD_XL domid"

# command option for the low version switch
CMD_NMAP_OPT=""

#################################################################
##
## option Change
## paramter flag: OPT
##
#################################################################
OPT_LOG_HOME=""
OPT_CONF_DUMP=0
OPT_ENV_UPDATE=0
OPT_ENV_INIT=0
OPT_STORE_WORKLOAD=0

#################################################################
##
## configure file refer global define
## parameter flag: CF
##           case define
## parameter flag: CF_VM
##           each vm define
## parameter flag: G_OPT
##           global option
## parameter flag: D_OPT
##           deault option
##
#################################################################
# global option for case, each element["key word"]="value
declare -A CF_GLOBAL_LST
# default option, each element["key word"]="value
declare -A CF_DEF_LST
# alias define for CF_GLOBAL_LIST value
## vm_count
declare CF_COUNT
# folder define
declare CF_FOLD_ALL CF_IMG_HOME CF_QCOW_HOME CF_ROOT_HOME CF_EXEC_HOME CF_WORK_HOME CF_HVM_HOME CF_LOG_HOME

# create qcow qemu command
declare CF_CMD_QEMU_IMG

# Case define
declare CF_CASE
declare CF_TIME_RUN CF_TIME_UNIT
declare CF_MAC_PER
declare CF_STORE_WORKLOAD
# dom0 execute workload
declare CF_EXEC_LST

# hvm: disk
declare -a CF_VM_IMG_LST CF_VM_E_IMG_LST
# hvm: vcpus / memory / vif
declare -a CF_VM_CPU_LST CF_VM_MEM_LST
# hvm: viridian
declare -a CF_VM_VIR_LST
# hvm: sdl / vnc
declare -a CF_VM_SDL_LST CF_VM_VNC_LST

# contrl qemu version
# hvm: device_model_version / device_model_override
declare -a CF_VM_QEMU_V_LST CF_VM_QEMU_O_LST

# GVT-g sepc option almost is default
# hvm: vgt vgt_low_gm_sz vgt_high_gm_sz vgt_fence_sz
declare -a CF_VM_GVT_G_LST CF_VM_GVT_L_LST CF_VM_GVT_H_LST CF_VM_GVT_F_LST

# define for dump value
# G: global
# option name/ option value/ important field
declare -a G_OPT_N_LST G_OPT_V_LST G_OPT_I_LST
# D: default
# option name/ option value/ important field
declare -a D_OPT_N_LST D_OPT_V_LST D_OPT_I_LST

#################################################################
##
## run time status define
## parameter flag: OS_RUN
##           each vm run time
##
#################################################################
# hvm: name; it is also all refer list keyword
declare -a OS_RUN_NAME_LST
# workload run type; 0: sequence (default)/1: parallel
declare -a OS_RUN_WORK_LST OS_RUN_WTYPE_LST
# hvm: guest mac address to fetch ip
declare -a OS_RUN_MAC_LST
# export DISPLAY option for each VM
declare -a OS_RUN_DISP_LST
# guest ip / guest vm id / guest vm status
declare -a OS_RUN_IP_LST OS_RUN_ID_LST OS_RUN_STATUS_LST
# vm idx mapping name
declare -A OS_RUN_IDX_NAME_LST
# define run time log path
declare OS_RUN_LOG_PATH

#################################################################
##
## option parse function
## function flag: func_opt
##
#################################################################
func_opt_parse_option()
{
    local -a _op_lst       #options control list(0/1)
    local -a _op_s_lst     #Short options list
    local -a _op_l_lst     #Long options list
    local -a _op_p_lst     #Paramter support options list (0/1)
    local -a _op_v_lst     #Default Value options list
    local -a _op_d_lst     #Description options list
    local _op_temp_script
    local _opt_count

    _func_dump_help()
    {
        local _idx=0
        echo "Usage: $FW_NAME [OPTION]"
        echo
        while [ $_idx -lt $_opt_count ];
        do
            [ "X""${_op_lst[$_idx]}" == "X0" ] && _idx=`expr $_idx + 1` && continue
            # display short option
            [ "${_op_s_lst[$_idx]}" ] && echo -ne '    -'"${_op_s_lst[$_idx]}"
            # have parameter
            [ "X""${_op_p_lst[$_idx]}" == "X1" ] && echo -ne " parameter"
            # display long option
            if [ "${_op_l_lst[$_idx]}" ];then
                # whether display short option
                [ "${_op_s_lst[$_idx]}" ] && echo -ne " |  " || echo -ne "    "
                echo -ne "--""${_op_l_lst[$_idx]}"
                [ "X""${_op_p_lst[$_idx]}" == "X1" ] && echo -ne " parameter"
            fi
            echo -e ""
            echo -e "\t""${_op_d_lst[$_idx]}"
            [ "${_op_v_lst[$_idx]}" ] && echo -e "\t""Default Value: ${_op_v_lst[$_idx]}"
            _idx=`expr $_idx + 1`
        done
        func_tool_exit_status "$FUNCNAME" $ERR_LV_PASS
    }

    _func_add_option()
    {
        local _idx=${#_op_lst[*]}
        _op_s_lst[$_idx]=$1 ; _op_l_lst[$_idx]=$2 ; _op_v_lst[$_idx]=$3 ; _op_d_lst[$_idx]=$4
        # default don't support parameter
        [ "$5" ] && _op_p_lst[$_idx]=$5 || _op_p_lst[$_idx]=0
        # default this option is open
        [ "$6" ] && _op_lst[$_idx]=$6 || _op_lst[$_idx]=1
    }

    _func_create_tmpbash()
    {
        local _idx=0
        local _short_opt _long_opt
        # loop to combine option which will be load by getopt
        while [ $_idx -lt $_opt_count ];
        do
            [ ${_op_lst[$_idx]} -ne 1 ] && _idx=`expr $_idx + 1` && continue
            _short_opt=$_short_opt"${_op_s_lst[$_idx]}"
            [ "$_long_opt" ] && _long_opt="$_long_opt"','
            _long_opt=$_long_opt"${_op_l_lst[$_idx]}"
            # option will accpect parameter
            [ ${_op_p_lst[$_idx]} -eq 1 ] && _short_opt=$_short_opt':' && _long_opt=$_long_opt':'
            _idx=`expr $_idx + 1`
        done
        _op_temp_script=`getopt -o "$_short_opt" --long "$_long_opt" -n "$FW_NAME" -- $@`
        if [ $? != 0 ] ; then echo "Error parse option" >&2 ; _func_dump_help ; fi
    }

    # add parameter
    _func_add_option "h" "help" "" "this message"
    _func_add_option "f" "conf" "$FW_CONF_FILE" "Replace configure file" 1
    _func_add_option "o" "output" "check with conf file log parameter" "Redefine output Log file path without change configure file" 1
    _func_add_option "u" "update" "" "Update image before run MTBF, after update script will quit" "" 1
    _func_add_option "i" "init" "" "run $FW_NAME to initialize environment, after init script will quit" "" 1
    _func_add_option "x" "xorg" "" "detect X Windows status & allow restart it." "" 0
    _func_add_option "c" "check" "" "check configure file option & environment" "" 1
    _func_add_option "s" "store" "" "store workload STAF log" "" 1
    _func_add_option "v" "version" "" "Dump this script current version"

    # generate the command to load 'getopt'
    _opt_count=${#_op_lst[*]}
    _func_create_tmpbash $@
    eval set -- "$_op_temp_script"

    # option function mapping
    while true ; do
        case "$1" in
            -h|--help)      _func_dump_help ; shift ;;
            -f|--conf)      echo "replace config file: $2" && FW_CONF_FILE="$2" ; shift 2 ;;
            -o|--output)    echo "redefine output: $2" && OPT_LOG_HOME="$2" ; shift 2 ;;
            -u|--update)    echo "Update image" && OPT_ENV_UPDATE=1; shift ;;
            -i|--init)      echo "init MTBF environment" && OPT_ENV_INIT=1 ; shift ;;
            -x|--xorg)      echo "Check X Widnows" ; shift ;;
            -c|--check)     OPT_CONF_DUMP=1 ; shift ;;
            -s|--store)     OPT_STORE_WORKLOAD=1 ; shift ;;
            -v|--version)   func_opt_dump_version ; shift ;;
            --) shift ; break ;;
            *) echo "Internal error!" ; func_tool_exit_status "$FUNCNAME" $ERR_LV_PARA ;;
        esac
    done

    return
    # store other parameter
    local -a _op_parm_lst  #Parameter list
    local _idx
    for arg do
        _idx=${#_op_parm_lst[*]}
        _op_parm_lst[$_idx]=$arg
    done
    echo "parameter: ${_op_parm_lst[*]}"
}

func_opt_dump_version()
{
    local splite_flag="#################################################################"
    local log_flag="##"
    local file="$FW_HOME/$FW_NAME"
    local end=`grep -n "$splite_flag" $file |awk -F ':' '{print $1;}'|sed '1d;3,$d'`
    head -n $end $file |grep "##" |sed 's/#//g;s/^ //g;/^[:space:]$/s/[:space:]//g;/^$/d'|sed '4s/^/\x1B[31m/g;4s/$/\x1B[0m/g'
    func_tool_exit_status "$FUNCNAME" $ERR_LV_PASS
}

#################################################################
##
## environment refer function
## function flag: func_mtbf_env
##
#################################################################
func_mtbf_env_check()
{
    mkdir -p $FW_TMP_FOLDER
    local _ret=$ERR_LV_PASS

    # check for xen service and check for kvm,how to check kvmgt??????
    if [ $VMM_TYPE -eq XEN];then
    [ ! -f /var/run/xenstored.pid ] && _ret=$ERR_LV_ENV && echo "please check xen service:\"xencommons\" already start"
     command check
    [[ `func_tool_check_cmd $CMD_XL` -ne 0 ]] && _ret=$ERR_LV_ENV && echo "please check have $CMD_XL command in system by \"which $CMD_XL\""
    [[ `func_tool_check_cmd $CMD_STAF` -ne 0 ]] && [[ -f "$STAF_HOME/STAFEnv.sh" ]] && source "$STAF_HOME/STAFEnv.sh"
    [[ `func_tool_check_cmd $CMD_STAF` -ne 0 ]] && _ret=$ERR_LV_ENV && echo "This script using $CMD_STAF as core command, please check it whether install in $STAF_HOME"
    [[ `func_tool_check_cmd $CMD_PARSE` -ne 0 ]] && _ret=$ERR_LV_ENV && echo "please check have $CMD_PARSE command in system by \"which $CMD_PARSE\", you install it."
    [[ `func_tool_check_cmd nmap` -ne 0 ]] && _ret=$ERR_LV_ENV && echo "please check have nmap command in system by \"which nmap\""
    [[ `func_tool_check_cmd nmap` -eq 0 ]] && [[ `nmap --help|grep '\-sn'` ]] && CMD_NMAP_OPT="-sn -n" || CMD_NMAP_OPT="-sP"
    fi
    if [ $VMM_TYPE -eq $KVM ];then
    _ret=$ERR_LV_PASS
    fi
    # bridge check
    local _cmd=`func_tool_check_cmd brctl`
    [[ $_cmd -ne 0 ]] && _ret=$ERR_LV_ENV
    [[ $_cmd -eq 0 ]] && BRG_HOST=`brctl show|sed 1d|grep -v 'vif'|awk '{print $1;}'`
    if [ "$BRG_HOST" ];then
        if [ $BRG_MULTI_SUPPORT -eq 0 ];then
            [[ `echo "$BRG_HOST"|sed 's/ /\n/g'|sort|uniq|wc -l` -ne 1 ]] && _ret=$ERR_LV_ENV && echo "Detect multi bridge"
        else
            echo "force setup bradg as xenbr0"
            BRG_HOST="xenbr0"
        fi
    else
        _ret=$ERR_LV_ENV && echo "Detect bridge abnormal, please check it"
    fi
    # setup ip fetch range
    [[ "$BRG_HOST" ]] && FETCH_IP=`ip route show|grep "\ src\ "|grep "dev $BRG_HOST"|awk '{print $1;}'`
    [[ ! "$BRG_HOST" ]] && FETCH_IP=`ip route show|grep "\ src\ "|awk '{print $1;}'`
    # setup Xorg check
    [[ `ps -ef |grep X|grep '\ \:0\ '` ]] && FETCH_XORG=1 || FETCH_XORG=0

    # process check
    local _tmp_file=$FW_TMP_FOLDER/$FUNCNAME.ps.$RANDOM
    ps -ef > $_tmp_file
    local _pid=`grep "$FW_NAME" $_tmp_file|grep -v "$FW_PID"`
    [[ "$_pid" ]] && _ret=$ERR_LV_ENV && echo "Detect $FW_NAME already run in current system by \"ps\" command, you can use \"pkill -9 $FW_NAME\" to kill it"
    _pid=`grep "$CMD_STAF" $_tmp_file|grep -v "$STAF_HOME"`
    [[ "$_pid" ]] && _ret=$ERR_LV_ENV && echo "Detect $CMD_STAF command already run in current system by \"ps\" command, you can use \"pkill -9 $CMD_STAF\" to kill it"
    rm -rf $_tmp_file

    # guest count check
    [[ $_ret -eq $ERR_LV_PASS ]] && \
        [[ `$CMD_XL_VMLIST |sed 1d|wc -l` -ne 0 ]] && echo "Warning: Multi-guest already detect please check it by \"$CMD_XL_VMLIST\"" && _ret=$ERR_LV_ENV

    # error exit
    if [ $_ret -ne $ERR_LV_PASS ];then
        echo -e "\nEnvironment detect catch error, please fix them"
        func_tool_exit_status "$FUNCNAME" $_ret
    fi
}

func_mtbf_env_init()
{
    rm -rf $CF_WORK_HOME $CF_EXEC_HOME $CF_ROOT_HOME/$FW_CASE_NAME.zip
    local OLD_PATH=$PWD
    mkdir -p $CF_ROOT_HOME
    cd $CF_ROOT_HOME
    wget -c -O $FW_CASE_NAME.zip "$FW_SER_URL/$FW_CASE_NAME.zip"
    [[ -f $FW_CASE_NAME.zip ]] && unzip $FW_CASE_NAME.zip << END
A
END
    rm -rf $FW_CASE_NAME.zip
    cd $OLD_PATH
    echo -e "\nenvironment init/reset finished, please check it again"
}

func_mtbf_env_clear()
{
    local _tmp_file=$FW_TMP_FOLDER/$FUNCNAME.ps.$RANDOM i j

    # 1. stop child process
    ps -ef > $_tmp_file
    for i in `grep "\ $FW_PID\ " $_tmp_file|awk '{print $2;}'`
    do
        # kill child process for child process
        for j in `grep "\ $i\ " $_tmp_file|awk '{print $2;}'`
        do
            [[ "$j" -eq "$i" ]] && continue
            func_tool_kill_pid $j $FUNCNAME
        done
        [[ "$i" -eq "$FW_PID" ]] && continue
        func_tool_kill_pid $i $FUNCNAME
    done

    # 2. destroy all guest
    func_vm_destroy_all

    # spec for system shutodwn no define
    sleep $TIME_CLEAR_WAIT

    # 3. kill exist workload process which maybe without reply
    for i in ${OS_RUN_IP_LST[*]};
    do
        ps -ef > $_tmp_file
        for j in `grep " $i " $_tmp_file|grep -v " $FW_PID "`
        do
            func_tool_kill_pid $j $FUNCNAME
        done
    done
    sleep $TIME_FW_WAIT

    rm -rf $_tmp_file
    rm -rf $FW_TMP_FOLDER
}

#################################################################
##
## configure file refer function
## flag: func_conf
##
#################################################################
func_conf_load()
{
    # load commnon option
    _func_get_common_value()
    {
        local _idx=${#G_OPT_N_LST[*]}
        G_OPT_N_LST[$_idx]="$1"
        G_OPT_V_LST[$_idx]=`$CMD_PARSE -f $FW_CONF_FILE -k "$1" -d "$2"`
        G_OPT_I_LST[$_idx]="$3"
        CF_GLOBAL_LST["$1"]="${G_OPT_V_LST[$_idx]}"
    }
    _func_get_common_value "vm_count" "7" 1
    CF_COUNT=`echo "${CF_GLOBAL_LST['vm_count']}"|awk '{print $1;}'`
    # folder define
    _func_get_common_value "image_home" "/home/img" 0
    CF_IMG_HOME="${CF_GLOBAL_LST['image_home']}"
    _func_get_common_value "qcow_home" "/home/qcow" 0
    CF_QCOW_HOME="${CF_GLOBAL_LST['qcow_home']}"
    _func_get_common_value "mtbf_home" "/home/$FW_CASE_NAME" 0
    CF_ROOT_HOME="${CF_GLOBAL_LST['mtbf_home']}"

    local _idx
    _idx=${#G_OPT_N_LST[*]}
    _func_get_common_value "log_home" "$CF_ROOT_HOME/log" 0
    CF_LOG_HOME="${CF_GLOBAL_LST['log_home']}"
    [[ "$OPT_LOG_HOME" ]] && \
        CF_LOG_HOME="$OPT_LOG_HOME" && \
        G_OPT_V_LST[$_idx]="$OPT_LOG_HOME" && \
        CF_GLOBAL_LST['log_home']="$OPT_LOG_HOME"

    [[ "X"`dirname $CF_LOG_HOME` == 'X.' ]] && CF_LOG_HOME=$CF_ROOT_HOME/$CF_LOG_HOME && G_OPT_V_LST[$_idx]=$OPT_LOG_HOME

    _func_get_common_value "exec_home" "$CF_ROOT_HOME/exec" 0
    CF_EXEC_HOME="${CF_GLOBAL_LST['exec_home']}"
    [[ "$CF_EXEC_HOME" ]] && [[ "X"`dirname $CF_EXEC_HOME` == 'X.' ]] && CF_EXEC_HOME=$CF_ROOT_HOME/$CF_EXEC_HOME
    _func_get_common_value "workload_home" "$CF_ROOT_HOME/workload" 1
    CF_WORK_HOME="${CF_GLOBAL_LST['workload_home']}"
    [[ "X"`dirname $CF_WORK_HOME` == 'X.' ]] && CF_WORK_HOME=$CF_ROOT_HOME/$CF_WORK_HOME
    _func_get_common_value "hvm_home" "$CF_ROOT_HOME/hvm" 0
    CF_HVM_HOME="${CF_GLOBAL_LST['hvm_home']}"
    [[ "X"`dirname $CF_HVM_HOME` == 'X.' ]] && CF_HVM_HOME=$CF_ROOT_HOME/$CF_HVM_HOME

    CF_FOLD_ALL="$CF_LOG_HOME $CF_QCOW_HOME $CF_ROOT_HOME $CF_EXEC_HOME $CF_WORK_HOME $CF_HVM_HOME"

    # image define
    _func_verify_image_path()
    {
        local _key="$1"
        [[ "X"`dirname ${CF_GLOBAL_LST["$_key"]}` == 'X.' ]] && CF_GLOBAL_LST["$_key"]=$CF_IMG_HOME/${CF_GLOBAL_LST["$_key"]}
    }
    
    _func_get_common_value "win7-32" "$CF_IMG_HOME/win7-32-perf.img" 1
    _func_verify_image_path "win7-32"
    _func_get_common_value "win7-64" "$CF_IMG_HOME/win7-64-perf.img" 1
    _func_verify_image_path "win7-64"
    _func_get_common_value "win8-64" "$CF_IMG_HOME/win8-64-perf.img" 1
    _func_verify_image_path "win8-64"

    # os constraint & os image mapping
    local -A img_conv_lst
    img_conv_lst['win7-32']="${CF_GLOBAL_LST['win7-32']}"
    img_conv_lst['win7-64']="${CF_GLOBAL_LST['win7-64']}"
    img_conv_lst['win8-64']="${CF_GLOBAL_LST['win8-64']}"
    local os_range=`echo ${!img_conv_lst[*]}`

    # create qcow qemu command
    _func_get_common_value "qemu-img" "$QEMU_IMG" 0
    CF_CMD_QEMU_IMG="${CF_GLOBAL_LST['qemu-img']}"

    # Case define
    # Name
    _func_get_common_value "name" "$FW_CASE_NAME" 0
    CF_CASE="${CF_GLOBAL_LST['name']}"
    _func_get_common_value "time" "40" 1
    CF_TIME_RUN="${CF_GLOBAL_LST['time']}"
    _func_get_common_value "unit" "h" 1
    CF_TIME_UNIT="${CF_GLOBAL_LST['unit']}"
    _func_get_common_value "mac_per" "00140102" 1
    CF_MAC_PER=`echo "${CF_GLOBAL_LST['mac_per']}"|tr [:lower:] [:upper:]|sed 's/://g'`
    _func_get_common_value "execute" "" 0
    local i
    for i in `echo ${CF_GLOBAL_LST['execute']}`;
    do
        _idx="${#CF_EXEC_LST[*]}"
        if [[ -f "$CF_EXEC_HOME/$i"".sh" ]];then
            CF_EXEC_LST[$_idx]="$CF_EXEC_HOME/$i"".sh"
        elif [[ -f "$CF_EXEC_HOME/$i" ]];then
            CF_EXEC_LST[$_idx]="$CF_EXEC_HOME/$i"
        elif [[ -f "$i"".sh" ]];then
            CF_EXEC_LST[$_idx]="$i"".sh"
        elif [[ -f "$i" ]];then
            CF_EXEC_LST[$_idx]="$i"
        else
            CF_EXEC_LST[$_idx]=""
        fi
    done

    # workload store
    _func_get_common_value "store_workload" "0" 1
    [[ $OPT_STORE_WORKLOAD -eq 1 ]] && CF_STORE_WORKLOAD=1 || CF_STORE_WORKLOAD="${CF_GLOBAL_LST['store_workload']}"

    _func_get_default_value()
    {
        local _idx=${#D_OPT_N_LST[*]}
        D_OPT_N_LST[$_idx]="$1"
        [[ "$2" ]] && D_OPT_V_LST[$_idx]=`$CMD_PARSE -f $FW_CONF_FILE -k "$1" -d "$2" -s "default"`
        [[ ! "$2" ]] && D_OPT_V_LST[$_idx]=`$CMD_PARSE -f $FW_CONF_FILE -k "$1" -d "" -s "default"`
        D_OPT_I_LST[$_idx]="$3"
        CF_DEF_LST["$1"]="${D_OPT_V_LST[$_idx]}"
    }
    _func_get_default_value "workload" "lucas" 1
    _func_get_default_value "run_type" "0" 1
    _func_get_default_value "os" "win7-64" 1
    local d_img="${img_conv_lst[${CF_DEF_LST['os']}]}"
    _func_get_default_value "ext" "" 1
    [[ "${CF_DEF_LST['ext']}" ]] && [[ "X"`dirname ${CF_DEF_LST['ext']}` == 'X.' ]] && CF_DEF_LST['ext']=$CF_IMG_HOME/${CF_DEF_LST['ext']}
    _func_get_default_value "vcpus" "2" 1
    _func_get_default_value "memory" "2048" 1
    _func_get_default_value "viridian" "1" 0
    _func_get_default_value "version" "qemu-xen??????" 0
    _func_get_default_value "override" "$QEMU_SYS" 0
    _func_get_default_value "vgt" "1" 0
    _func_get_default_value "vgt_low_gm_sz" "128" 0
    _func_get_default_value "vgt_high_gm_sz" "384" 0
    _func_get_default_value "vgt_fence_sz" "4" 0
    _func_get_default_value "display" "" 0
    _func_get_default_value "sdl" "0" 0
    _func_get_default_value "vnc" "1" 0

    # load for each guest os
    local _tmp_mac=$FW_TMP_FOLDER/mac.$RANDOM
    nmap $CMD_NMAP_OPT $FETCH_IP 2>/dev/null |grep 'MAC'|sed 's/.*[[:blank:]]\([0-9A-F].:[0-9A-F].:[0-9A-F].:[0-9A-F].:[0-9A-F].:[0-9A-F].\).*/\1/' > $_tmp_mac
    _func_get_common_value "guest" "" 0
    local _tmp_guest="${CF_GLOBAL_LST['guest']}"
    local -a guest_lst
    for i in `echo $_tmp_guest`;
    do
        _idx=${#guest_lst[*]}
        guest_lst[$_idx]="$i"
    done

    _func_generate_mac()
    {
        # mac format: XX:XX:XX:XX:XX:XX length is 12
        local _l= _pfmt="" _mac="" _rand= _eff= _count=5
        [[ ${#CF_MAC_PER} -ge 12 ]] && echo $CF_MAC_PER && return
        while [ $_count -gt 0 ];
        do
            _l=`expr 12 - ${#CF_MAC_PER}` ; _rand="" ; _pfmt="" ; _eff=1
            [[ `expr $_l - 8` -gt 0 ]] && _l=`expr $_l - 8` && _pfmt="%04X%04X" && _rand="$RANDOM $RANDOM"
            [[ `expr $_l - 4` -gt 0 ]] && _l=`expr $_l - 4` && _pfmt="%04X" && _rand="$RANDOM"
            _pfmt=$_pfmt"%0"$_l"X"
            [[ $_l -eq 4 ]] && _rand="$_rand $RANDOM"
            [[ $_l -eq 3 ]] && _rand="$_rand "`expr $RANDOM % 4096`
            [[ $_l -eq 2 ]] && _rand="$_rand "`expr $RANDOM % 256`
            [[ $_l -eq 1 ]] && _rand="$_rand "`expr $RANDOM % 16`
            _mac="$CF_MAC_PER"`printf "$_pfmt" $_rand`
            _mac=`echo $_mac|sed 's/../&:/g'|sed 's/:$//g'`
            [[ `echo "${OS_RUN_MAC_LST[*]}" |grep "$_mac"` ]] && _eff=0
            [[ `grep "$_mac" $_tmp_mac` ]] && _eff=0
            [[ $_eff -eq 1 ]] && break
            _count=`expr $_count - 1`
        done
        echo $_mac
    }

    _func_load_vm_option()
    {
        local _key="$1"
        local _idx="$2"
        $CMD_PARSE -f $FW_CONF_FILE -k "$_key" -d "${CF_DEF_LST[$_key]}" -s "${OS_RUN_NAME_LST[$_idx]}"
    }
    local _os
    _idx=0
    while [ $_idx -lt $CF_COUNT ];
    do
        [[ "$_idx" -lt "${#guest_lst[*]}" ]] && OS_RUN_NAME_LST[$_idx]="${guest_lst[$_idx]}" || OS_RUN_NAME_LST[$_idx]="def_""$_idx"
        OS_RUN_WORK_LST[$_idx]=`_func_load_vm_option "workload" $_idx`
        OS_RUN_WTYPE_LST[$_idx]=`_func_load_vm_option "run_type" $_idx`

        # for HVM file created
        _os=`_func_load_vm_option "os" $_idx`
        # convert OS to image
        [[ `echo $os_range|grep "$_os"` ]] && CF_VM_IMG_LST[$_idx]=`echo ${img_conv_lst[$_os]}`
        CF_VM_E_IMG_LST[$_idx]=`_func_load_vm_option "ext" $_idx`
        if [[ "${CF_VM_E_IMG_LST[$_idx]}" ]];then
            [[ "X"`dirname ${CF_VM_E_IMG_LST[$_idx]}` == 'X.' ]] && CF_VM_E_IMG_LST[$_idx]=$CF_IMG_HOME/${CF_VM_E_IMG_LST[$_idx]}
        fi
        CF_VM_CPU_LST[$_idx]=`_func_load_vm_option "vcpus" $_idx`
        CF_VM_MEM_LST[$_idx]=`_func_load_vm_option "memory" $_idx`
        OS_RUN_MAC_LST[$_idx]=`_func_load_vm_option "mac" $_idx`
        [[ ! "${OS_RUN_MAC_LST[$_idx]}" ]] && OS_RUN_MAC_LST[$_idx]=`_func_generate_mac`
        OS_RUN_DISP_LST[$_idx]=`_func_load_vm_option "display" $_idx`
        CF_VM_VIR_LST[$_idx]=`_func_load_vm_option "viridian" $_idx`
        CF_VM_SDL_LST[$_idx]=`_func_load_vm_option "sdl" $_idx`
        CF_VM_VNC_LST[$_idx]=`_func_load_vm_option "vnc" $_idx`
        CF_VM_QEMU_V_LST[$_idx]=`_func_load_vm_option "version" $_idx`
        CF_VM_QEMU_O_LST[$_idx]=`_func_load_vm_option "override" $_idx`
        CF_VM_GVT_G_LST[$_idx]=`_func_load_vm_option "vgt" $_idx`
        CF_VM_GVT_L_LST[$_idx]=`_func_load_vm_option "vgt_low_gm_sz" $_idx`
        CF_VM_GVT_H_LST[$_idx]=`_func_load_vm_option "vgt_high_gm_sz" $_idx`
        CF_VM_GVT_F_LST[$_idx]=`_func_load_vm_option "vgt_fence_sz" $_idx`

        OS_RUN_IP_LST[$idx]=""
        OS_RUN_ID_LST[$idx]=""
        # store key to mapping name
        OS_RUN_IDX_NAME_LST["${OS_RUN_NAME_LST[$_idx]}"]="$_idx"
        _idx=${#OS_RUN_NAME_LST[*]}
    done

    rm $_tmp_mac
}

func_conf_dump()
{
    local _idx=0 _count=${#G_OPT_N_LST[*]}
    echo -e "\n\tCase refer define\n"
    while [ $_idx -lt $_count ];do
        echo -ne "\t${G_OPT_N_LST[$_idx]}\t\t"
        [ ${#G_OPT_N_LST[$_idx]} -lt 8 ] && echo -ne "\t"
        echo -e ":\t${G_OPT_V_LST[$_idx]}"
        _idx=`expr $_idx + 1`
    done
    echo -e "\n\tDefault guest refer define(hide)\n"
    _idx=0; _count=${#D_OPT_N_LST[*]}
    while [ $_idx -lt $_count ];do
        [[ ${D_OPT_I_LST[$_idx]} -eq 1 ]] && _idx=`expr $_idx + 1` && continue
        echo -ne "\t\t${D_OPT_N_LST[$_idx]}\t"
        [ ${#D_OPT_N_LST[$_idx]} -lt 8 ] && echo -ne "\t"
        echo -e ":\t${D_OPT_V_LST[$_idx]}"
        _idx=`expr $_idx + 1`
    done

    _func_dump_hvm_opt()
    {
        [[ "${#2}" -ge 8 ]] && [[ "$1" != "${CF_DEF_LST[$2]}" ]] && echo -e "\t\t$2\t:\t$1" && return
        [[ "${#2}" -lt 8 ]] && [[ "$1" != "${CF_DEF_LST[$2]}" ]] && echo -e "\t\t$2\t\t:\t$1" && return
    }
    echo -e "\n\tguest define (count: ${#OS_RUN_NAME_LST[*]})\n"
    _idx=0; _count=${#OS_RUN_NAME_LST[*]}
    while [ $_idx -lt $_count ];do
        echo -e "\n\t$_idx:==============================================\n"
        echo -e "\t\tname\t\t:\t${OS_RUN_NAME_LST[$_idx]}"
        echo -e "\t\tworkload\t:\t${OS_RUN_WORK_LST[$_idx]}"
        [[ "${OS_RUN_WTYPE_LST[$_idx]}" -eq 1 ]] && echo -e "\t\ttype\t\t:\tparallel" || echo -e "\t\ttype\t\t:\tsequence"
        echo -e "\t\timage\t\t:\t${CF_VM_IMG_LST[$_idx]}"
        [[ "${CF_VM_E_IMG_LST[$_idx]}" ]] && echo -e "\t\textern image\t:\t${CF_VM_E_IMG_LST[$_idx]}"
        echo -e "\t\tvcpus\t\t:\t${CF_VM_CPU_LST[$_idx]}"
        echo -e "\t\tmemory\t\t:\t${CF_VM_MEM_LST[$_idx]}"
        echo -e "\t\tMAC address\t:\t${OS_RUN_MAC_LST[$_idx]}"
        _func_dump_hvm_opt "${OS_RUN_DISP_LST[$_idx]}" "display"
        _func_dump_hvm_opt "${CF_VM_VIR_LST[$_idx]}" "viridian"
        _func_dump_hvm_opt "${CF_VM_SDL_LST[$_idx]}" "sdl"
        _func_dump_hvm_opt "${CF_VM_VNC_LST[$_idx]}" "vnc"
        _func_dump_hvm_opt "${CF_VM_QEMU_V_LST[$_idx]}" "version"
        _func_dump_hvm_opt "${CF_VM_QEMU_O_LST[$_idx]}" "override"
        _func_dump_hvm_opt "${CF_VM_GVT_G_LST[$_idx]}" "vgt"
        _func_dump_hvm_opt "${CF_VM_GVT_L_LST[$_idx]}" "vgt_low_gm_sz"
        _func_dump_hvm_opt "${CF_VM_GVT_H_LST[$_idx]}" "vgt_high_gm_sz"
        _func_dump_hvm_opt "${CF_VM_GVT_F_LST[$_idx]}" "vgt_fence_sz"
        _idx=`expr $_idx + 1`
    done

    # conflict VM name
    echo -e "\n\tProblem report:"
    _count=`echo ${OS_RUN_NAME_LST[*]}|sed 's/ /\n/g' |sort|uniq|wc -l`
    if [[ $_count -ne "${#OS_RUN_NAME_LST[*]}" ]];then
        echo -e "\n\t\tGuest name conflict"
        echo -e "\t\t\t${OS_RUN_NAME_LST[*]}"
    fi

    # error MAC
    _count=0
    [[ `echo $CF_MAC_PER|sed 's/://g'|sed 's/[0-9A-F]//g'` ]] && \
        echo -e "\n\t\tmac_per value: "`echo $CF_MAC_PER|sed 's/://g'|sed 's/[0-9A-F]//g'`" can not generate correct mac: ${CF_GLOBAL_LST['mac_per']}"
    [[ ${#CF_MAC_PER} -ge 12 ]] && echo -e "\n\t\tmac_per length ${#CF_MAC_PER} can not generate correct mac: ${CF_GLOBAL_LST['mac_per']}"

    # calculate CPU
    _count=`echo ${CF_VM_CPU_LST[*]}|awk '{for(i=1;i<=NF;i++) sum+=$i} END { print sum}'`
    local _tmp_count=`grep processor /proc/cpuinfo|wc -l`
    _count=`expr $_count + $_tmp_count`
    _tmp_count=`$CMD_XL_INFO|grep 'nr_cpus'|sed 's/[[:blank:]]//g'|awk -F ':' '{print $2;}'`
    _count=`expr $_count / 2`
    if [[ $_tmp_count -lt $_count ]];then
        echo -e "\n\t\tCPU\t:\tcurrent Max CPU: $_tmp_count"
        echo -e "\t\t\t${CF_VM_CPU_LST[*]}"
    fi

    # calculate Memory
    _count=`echo ${CF_VM_MEM_LST[*]}|awk '{for(i=1;i<=NF;i++) sum+=$i} END { print sum }'`
    _tmp_count=`$CMD_XL_INFO|grep 'free_memory'|sed 's/[[:blank:]]//g'|awk -F ':' '{print $2;}'`
    if [[ $_tmp_count -lt $_count ]];then
        echo -e "\n\t\tMemory\t:\tcurrent free: $_tmp_count"
        echo -e "\t\t\t${CF_VM_MEM_LST[*]}"
    fi

    # dom0 execute check
    _count=0
    if [[ ${#CF_EXEC_LST[*]} -eq 0 ]];then
        echo -e "\n\t\tWarning!! Dom0 no execute need to run"
    else
        local _cmd
        for _cmd in `echo ${CF_EXEC_LST[*]}`;
        do
            [[ `func_tool_check_cmd $_cmd` -ne 0 ]] && _count=`expr $_count + 1`
        done
        if [[ $_count -ne 0 ]];then
            echo -e "\n\t\tExecute\t:\tcurrent: ${CF_EXEC_LST[*]}"
            echo -e "\t\t\texec_home=${CF_GLOBAL_LST['exec_home']}"
            echo -e "\t\t\texecute=${CF_GLOBAL_LST['execute']}"
        fi
    fi

    # image file check
    func_img_check

    # configure conflict check
    _func_get_parameter_count()
    {
        echo $#
    }
    # global config
    local i
    for i in ${!CF_GLOBAL_LST[*]}
    do
        # allow more option skip check
        [[ "$i" == "guest" ]] && continue
        [[ "$i" == "execute" ]] && continue
        [[ `_func_get_parameter_count ${CF_GLOBAL_LST["$i"]}` -ne 1 ]] && echo -e "\n\t\tGlobal define: \"$i\" configure conflict"
    done
    # default config
    for i in ${!CF_DEF_LST[*]}
    do
        # allow more option skip check
        [[ "$i" == "workload" ]] && continue
        [[ "$i" == "ext" ]] && [[ `_func_get_parameter_count ${CF_DEF_LST["$i"]}` -gt 1 ]] && echo -e "\n\t\tDefault define: \"$i\" configure conflict"
        [[ "$i" == "ext" ]] && continue
        [[ "$i" == "display" ]] && [[ `_func_get_parameter_count ${CF_DEF_LST["$i"]}` -gt 1 ]] && echo -e "\n\t\tDefault define: \"$i\" configure conflict"
        [[ "$i" == "display" ]] && continue
        [[ `_func_get_parameter_count ${CF_DEF_LST["$i"]}` -ne 1 ]] && echo -e "\n\t\tDefault define: \"$i\" configure conflict"
    done

    # each VM
    _func_check_vm_opt()
    {
        [[ `_func_get_parameter_count $1` -ne 1 ]] && echo -e "\n\t\tIn $2: \"$3\" configure conflict"
    }
    _idx=0; _count=${#OS_RUN_NAME_LST[*]}
    local _vm_name
    while [ $_idx -lt $_count ]
    do
        _vm_name="${OS_RUN_NAME_LST[$_idx]}"
        _func_check_vm_opt "${CF_VM_IMG_LST[$_idx]}" "$_vm_name" "os"
        _func_check_vm_opt "${OS_RUN_WTYPE_LST[$_idx]}" "$_vm_name" "run_type"
        [[ ! `echo ${OS_RUN_WORK_LST[$_idx]}` ]] && echo -e "\n\t\tWarning!! In $_vm_name no workload need to run"
        [[ `_func_get_parameter_count ${CF_VM_E_IMG_LST[$_idx]}` -gt 1 ]] && echo -e "\n\t\tIn $_vm_name: \"ext\" configure conflict"
        _func_check_vm_opt "${CF_VM_CPU_LST[$_idx]}" "$_vm_name" "vcpus"
        _func_check_vm_opt "${CF_VM_MEM_LST[$_idx]}" "$_vm_name" "memory"
        [[ `_func_get_parameter_count ${OS_RUN_DISP_LST[$_idx]}` -gt 1 ]] && echo -e "\n\t\tIn $_vm_name: \"display\" configure conflict"
        # display effect
        [[ "${OS_RUN_DISP_LST[$_idx]}" ]] && [[ ! `ps -ef|grep X |grep "\ :${OS_RUN_DISP_LST[$_idx]}\ "` ]] && \
            echo -e "\n\t\tIn $_vm_name: \"display\" = ${OS_RUN_DISP_LST[$_idx]} Miss match environment"
        _func_check_vm_opt "${CF_VM_VIR_LST[$_idx]}" "$_vm_name" "viridian"
        _func_check_vm_opt "${CF_VM_SDL_LST[$_idx]}" "$_vm_name" "sdl"
        _func_check_vm_opt "${CF_VM_VNC_LST[$_idx]}" "$_vm_name" "vnc"
        _func_check_vm_opt "${CF_VM_QEMU_V_LST[$_idx]}" "$_vm_name" "version"
        _func_check_vm_opt "${CF_VM_QEMU_O_LST[$_idx]}" "$_vm_name" "override"
        _func_check_vm_opt "${CF_VM_GVT_G_LST[$_idx]}" "$_vm_name" "vgt"
        _func_check_vm_opt "${CF_VM_GVT_L_LST[$_idx]}" "$_vm_name" "vgt_low_gm_sz"
        _func_check_vm_opt "${CF_VM_GVT_H_LST[$_idx]}" "$_vm_name" "vgt_high_gm_sz"
        _func_check_vm_opt "${CF_VM_GVT_F_LST[$_idx]}" "$_vm_name" "vgt_fence_sz"
        _idx=`expr $_idx + 1`
    done

    echo -e "\n\tconfigure file check finished."
}

func_conf_create()
{
    local _tmp_conf=$FW_CONF_FILE
    FW_CONF_FILE="/dev/null"
    func_conf_load
    FW_CONF_FILE=$_tmp_conf
    mkdir -p `dirname $FW_CONF_FILE`

    > $FW_CONF_FILE
    local _idx=0
    local _count=${#G_OPT_N_LST[*]}
    while [ $_idx -lt $_count ];do
        [[ "${G_OPT_I_LST[$_idx]}" -eq 1 ]] && echo "${G_OPT_N_LST[$_idx]}=${G_OPT_V_LST[$_idx]}" >> $FW_CONF_FILE
        _idx=`expr $_idx + 1`
    done
    echo "guest=${OS_RUN_NAME_LST[*]}" >> $FW_CONF_FILE
    echo >> $FW_CONF_FILE
    
    echo "[default]" >> $FW_CONF_FILE
    _idx=0
    _count=${#D_OPT_N_LST[*]}
    while [ $_idx -lt $_count ];do
        [[ "${D_OPT_I_LST[$_idx]}" -eq 1 ]] && echo "${D_OPT_N_LST[$_idx]}=${D_OPT_V_LST[$_idx]}" >> $FW_CONF_FILE
        _idx=`expr $_idx + 1`
    done
    echo >> $FW_CONF_FILE

    _idx=0
    _count=${#OS_RUN_NAME_LST[*]}
    while [ $_idx -lt $_count ];do
        echo "[${OS_RUN_NAME_LST[$_idx]}]" >> $FW_CONF_FILE
        echo "workload=${OS_RUN_WORK_LST[$_idx]}" >> $FW_CONF_FILE
        echo "run_type=${OS_RUN_WTYPE_LST[$_idx]}" >> $FW_CONF_FILE
        echo "os=${CF_DEF_LST['os']}" >> $FW_CONF_FILE
        echo >> $FW_CONF_FILE
        _idx=`expr $_idx + 1`
    done
}

#################################################################
##
## tools function:complex command
## function flag: func_tool
##
#################################################################
func_tool_check_cmd()
{
    which $1 2>&1>/dev/null
    local _cmd=$?
    echo $_cmd
}

func_tool_cmd_run_pass()
{
    # exit function record which will helpful with trace
    [[ "$2" ]] && local _fun_name="$2" || local _fun_name="$FUNCNAME"
    # run command
    `echo $1`
    # check result
    [ $? -ne 0 ] && echo "CMD failed: \"$1\"" &&  func_tool_exit_status "$_fun_name" $ERR_LV_BLOCK
}

func_tool_cmd_loop_pass()
{
    # exit function record which will helpful with trace
    [[ "$2" ]] && local _fun_name="$2" || local _fun_name="$FUNCNAME"
    # run command
    mkdir -p $OS_RUN_LOG_PATH/cmd
    local _idx=0 _log_file="$OS_RUN_LOG_PATH/cmd/"`func_tool_get_time` _tmp_file=$FW_TMP_FOLDER/cmd.$RANDOM
    while [ $_idx -lt $FW_CMD_LOOP ]
    do
        `echo $1`  2>&1 1>$_tmp_file &
        [[ $? -eq 0 ]] && echo -e "$_idx:\t$1\tpass" >> $_log_file && cat $_tmp_file >> $_log_file && break
        echo -e "$_idx:\t$1\tfailed" >> $_log_file
        cat $_tmp_file >> $_log_file
        _idx=`expr $_idx + 1`
        sleep $TIME_FW_WAIT
    done
    rm $_tmp_file
    # check result
    [ $_idx -ge $FW_CMD_LOOP ] && echo "CMD failed: \"$1\"" &&  func_tool_exit_status "$_fun_name" $ERR_LV_BLOCK
}

func_tool_check_file()
{
    [[ ! -f $1 ]]  && echo -e "\t\tCheck for $1 exist Error. $2"
}

func_tool_name_to_id()
{
    echo ${OS_RUN_IDX_NAME_LST["$1"]}
}

func_tool_get_time()
{
    date +0%u_%R
}

func_tool_convert_utc_time()
{
    date --date="@$1" +0%u_%T
}

func_tool_exit_status()
{
    echo -ne "\n\t$FW_NAME exit with $1 status"
    case "$2" in
        "$ERR_LV_PASS")     echo ": pass" ;;
        "$ERR_LV_ENV")      echo ": environment" ;;
        "$ERR_LV_PARA")     echo ": parameter" ;;
        "$ERR_LV_BLOCK")    echo ": block" ;;
        "$ERR_LV_ERR")      echo ": error" ;;
        "$ERR_LV_CHILD")    echo ": child pid" ;;
        "$ERR_LV_UNKNOW")   echo ": unknow" ;;
        *)                  echo ": undefine error status"
    esac
    echo -e "\tvalue is $2"
    exit "$2"
}

func_tool_kill_pid()
{
    local _pid="$1" _name="$2"
    [[ "$_name" ]] && echo -n "In $name"
    echo "Kill child process $_pid: "`ps -p $_pid|sed 1d|awk '{print $NF;}'`
    kill -9 $_pid 2>/dev/null
}

#################################################################
##
## image file operation
## function flag: func_img
##
#################################################################
func_img_check()
{
    local i
    for i in `echo ${CF_VM_IMG_LST[*]}|sed 's/ /\n/g' |sort|uniq`;
    do
        func_tool_check_file $i "Please check $CF_IMG_HOME"
    done

    for i in `echo ${CF_VM_E_IMG_LST[*]}|sed 's/ /\n/g' |sort|uniq`;
    do
        func_tool_check_file $i "Please check $CF_IMG_HOME"
    done
}

func_img_update()
{
    # miss loop driver in current kernel build
    [[ ! -e "/dev/loop0" ]] && modprobe loop
    [[ `func_tool_check_cmd kpartx` -ne 0 ]] && echo "In $FUNCNAME will use kpartx command, you need install it" && return
    [[ `func_tool_check_cmd unix2dos` -ne 0 ]] && echo "In $FUNCNAME will use unix2dos command, you need install it" && return
    local i _loop_dev
    local _mount_path=/mnt
    for i in `echo ${CF_VM_IMG_LST[*]}|sed 's/ /\n/g' |sort|uniq`;
    do
        echo "Update image: $i"
        kpartx -a -v $i
        sleep "$TIME_FW_WAIT"
        # Here for the GuestOS image (Windows) disk partition setup rule
        # p1 : Windows Boot (hide) partition
        # p2 : Primary partition (C:)
        _loop_dev=`losetup -a|grep "$i"|awk -F ":" '{print $1;}'|awk -F '/' '{print $3;}'`"p2"
        mount /dev/mapper/"$_loop_dev" $_mount_path
        # clear image's store
        rm -rf $_mount_path/$FW_CASE_NAME
        cp -rf $CF_WORK_HOME $_mount_path/$FW_CASE_NAME
        rm -rf $_mount_path/$FW_CASE_NAME/*.sh
        unix2dos $_mount_path/$FW_CASE_NAME/*

        umount $_mount_path
        kpartx -d -v $i
        echo "update finish"
        sleep "$TIME_FW_WAIT"
    done
}

#################################################################
##
## help function separate from script in xts
## function flag: func_vm
##
#################################################################
func_vm_covert_name_to_id()
{
    $CMD_XL_DOMID "$1" 2>/dev/null
}

func_vm_destroy_all()
{
    local i
    for i in `$CMD_XL_VMLIST|sed '1d'|awk '{print $2;}'`;
    do
        func_tool_cmd_loop_pass "$CMD_XL_DESTROY $i" "$FUNCNAME"
    done
    sleep $TIME_XL_WAIT
}

func_vm_status()
{
    local _idx=$1 _id=`func_vm_covert_name_to_id ${OS_RUN_NAME_LST[$_idx]}`
    [[ ! "$_id" ]] && OS_RUN_STATUS_LST[$_idx]="" && return
    OS_RUN_STATUS_LST[$_idx]=`$CMD_XL_STATUS $_id|sed '1d'|awk '{print $5;}'|sed 's/-//g'`
    [[ ! "${OS_RUN_STATUS_LST[$_idx]}" ]] && OS_RUN_STATUS_LST[$_idx]='-'
}

func_vm_refresh_all_id()  # name to vm id
{
    local _idx=0 _id
    local _count=${#OS_RUN_NAME_LST[*]}
    while [ $_idx -lt $_count ];
    do
        _id=`func_vm_covert_name_to_id ${OS_RUN_NAME_LST[$_idx]}`
        echo "$FUNCNAME: ${OS_RUN_NAME_LST[$_idx]} catch vm-id: $_id"
        [[ "$_id" -ne "${OS_RUN_ID_LST[$_idx]}" ]] && echo "Catch ${OS_RUN_NAME_LST[$_idx]} vm_id CHANGE from ${OS_RUN_ID_LST[$_idx]} to $_id"
        OS_RUN_ID_LST[$_idx]="$_id"
        _idx=`expr $_idx + 1`
    done
}

func_vm_refresh_all_ip()  # mac to vm ip
{
    local _idx=0 _ip
    local _count=${#OS_RUN_MAC_LST[*]}
    local _ip_result=`nmap $CMD_NMAP_OPT $FETCH_IP`
    while [ $_idx -lt $_count ];
    do
        _ip=`echo $_ip_result|sed 's/Nmap/\nNmap/g'|grep "${OS_RUN_MAC_LST[$_idx]}"|sed  's/.*[^0-9]\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/'`
        [[ ! "$_ip" ]] && _idx=`expr $_idx + 1` && continue
        [[ "$_ip" != "${OS_RUN_IP_LST[$_idx]}" ]] && \
            echo "Catch ${OS_RUN_NAME_LST[$_idx]} vm_ip CHANGE from ${OS_RUN_IP_LST[$_idx]} to $_ip" && \
            OS_RUN_IP_LST[$_idx]=$_ip
        ping ${OS_RUN_IP_LST[$_idx]} -c 2 2>&1 >/dev/null
        [[ $? -ne 0 ]] && OS_RUN_IP_LST[$_idx]=""
        _idx=`expr $_idx + 1`
    done
}

func_vm_detect_alive()
{
    local _idx="$1" _id=`func_vm_covert_name_to_id ${OS_RUN_NAME_LST[$_idx]}`
    # miss guest vm id means vm crash
    [[ ! $_id ]] && return 1
    ping ${OS_RUN_IP_LST[$_idx]} -c 5 1>/dev/null
    # ping fail means guest die
    [[ $? -ne 0 ]] && return 1
    $CMD_STAF ${OS_RUN_IP_LST[$_idx]} ping ping 2>&1 >/dev/null
    # ping pass & staf ping failed means guest without request response
    [[ $? -ne 0 ]] && return 1
    return 0
}

func_vm_detect_all_alive()  # ip to alive detect
{
    local _idx=0 _ip _ret
    local _count=${#OS_RUN_IP_LST[*]}
    while [ $_idx -lt $_count ];
    do
        func_vm_detect_alive $_idx
        [[ $? -eq 1 ]] && _ret="$_ret $_idx"
        _idx=`expr $_idx + 1`
    done
    # record result is which ping failed / staf ping failed
    echo $_ret|sed 's/ /\n/g' |sort|uniq
}

func_vm_start()
{
    local _idx="$1"
    local _hvm="$CF_HVM_HOME/""${OS_RUN_NAME_LST[$_idx]}"".hvm"
    # redirect DISPLAY
    [[ "${OS_RUN_DISP_LST[$_idx]}" ]] && export DISPLAY=":""${OS_RUN_DISP_LST[$_idx]}"
    [[ ! "${OS_RUN_DISP_LST[$_idx]}" ]] && unset DISPLAY
    func_tool_cmd_loop_pass "bash $_hvm " "$FUNCNAME"
    sleep $TIME_XL_WAIT
}

#################################################################
##
## run case refer host environment init
## function flag: func_run
##
#################################################################
func_run_create_all_hvm()
{

    local _idx=0
    local _count=${#OS_RUN_NAME_LST[*]}
    local _hvm_file _qcow_file _qcow_e_file
    mkdir -p $CF_HVM_HOME

    while [ $_idx -lt $_count ];do
        _hvm_file="$CF_HVM_HOME/""${OS_RUN_NAME_LST[$_idx]}"".hvm"
        echo "$FUNCNAME: create hvm file: $_hvm_file for ${OS_RUN_NAME_LST[$_idx]}"
        _qcow_file="$CF_QCOW_HOME/"`basename ${CF_VM_IMG_LST[$_idx]}`".qcow.""$_idx"
        [[ "${CF_VM_E_IMG_LST[$_idx]}" ]] && _qcow_e_file="$CF_QCOW_HOME/"`basename ${CF_VM_E_IMG_LST[$_idx]}`".qcow.""$_idx"
        func_tool_check_file $_qcow_file
        [[ "$_qcow_e_file" ]] && func_tool_check_file $_qcow_e_file
        
if [ $VMM_TYPE -eq $XEN];then

        cat > $_hvm_file << END
builder     ='hvm'
vcpus       = ${CF_VM_CPU_LST[$_idx]}
memory      = ${CF_VM_MEM_LST[$_idx]}
name        = "${OS_RUN_NAME_LST[$_idx]}"
vif         = [ 'type=ioemu,bridge=$BRG_HOST,mac=${OS_RUN_MAC_LST[$_idx]},model=e1000' ]
END
        [[ ! "$_qcow_e_file" ]] && echo "disk        = ['$_qcow_file,qcow2,hda,w']" >> $_hvm_file
        [[ "$_qcow_e_file" ]] && echo "disk        = ['$_qcow_file,qcow2,hda,w', '$_qcow_e_file,qcow2,hdb,w']" >> $_hvm_file
        cat >> $_hvm_file << END
#soundhw    = "ac97"
#stdvga     = 1
viridian    = ${CF_VM_VIR_LST[$_idx]}

device_model_version    = '${CF_VM_QEMU_V_LST[$_idx]}'
device_model_override   = '${CF_VM_QEMU_O_LST[$_idx]}'
boot        = "dc"
opengl      = 0
#vncpasswd   = ''
serial      = 'pty'
usb         = 1
usbdevice   = 'tablet'
sdl         = ${CF_VM_SDL_LST[$_idx]}
vnc         = ${CF_VM_VNC_LST[$_idx]}

keymap      = 'en-us'

# VGT Project
vgt             = ${CF_VM_GVT_G_LST[$_idx]}
vgt_low_gm_sz   = ${CF_VM_GVT_L_LST[$_idx]}
vgt_high_gm_sz  = ${CF_VM_GVT_H_LST[$_idx]}
vgt_fence_sz    = ${CF_VM_GVT_F_LST[$_idx]}
END
else 
    echo "$QEMU_SYS -enable-kvm -M pc -cpu host \
-machine kernel_irqchip=on -m ${CF_VM_MEM_LST[$_idx]} \
-smp ${CF_VM_CPU_LST[$_idx]} \
-hda $_qcow_file -vgt -vga vgt -vgt_low_gm_sz ${CF_VM_GVT_L_LST[$_idx]} \
-vgt_high_gm_sz ${CF_VM_GVT_H_LST[$_idx]} \
-vgt_fence_sz ${CF_VM_GVT_F_LST[$_idx]} -vnc :$_idx \
-net nic,model=e1000,macaddr=${OS_RUN_MAC_LST[$_idx]} \
-net tap,script=/etc/kvm/qemu-ifup" > $_hvm_file
fi


        _idx=`expr $_idx + 1`
    done

    # after created hvm release uesless var which use to create HVM file
    unset CF_VM_CPU_LST CF_VM_MEM_LST CF_VM_VIR_LST
    unset CF_VM_SDL_LST CF_VM_VNC_LST
    unset CF_VM_QEMU_V_LST CF_VM_QEMU_O_LST
    unset CF_VM_GVT_G_LST CF_VM_GVT_L_LST CF_VM_GVT_H_LST CF_VM_GVT_F_LST
}

func_run_backup_qcow()
{
    local _idx="$1" _time="$2"
    local _qcow_file="$CF_QCOW_HOME/"`basename ${CF_VM_IMG_LST[$_idx]}`".qcow.""$_idx"
    mv $_qcow_file "$_qcow_file""-""$_time"
    if [[ "${CF_VM_E_IMG_LST[$_idx]}" ]];then
        _qcow_file="$CF_QCOW_HOME/"`basename ${CF_VM_E_IMG_LST[$_idx]}`".qcow.""$_idx"
        mv $_qcow_file "$_qcow_file""-""$_time"
    fi
}

func_run_rebuild_qcow()
{
    local _idx="$1"
    local _qcow_file="$CF_QCOW_HOME/"`basename ${CF_VM_IMG_LST[$_idx]}`".qcow.""$_idx"
    rm -rf $_qcow_file
    func_tool_cmd_run_pass "$CF_CMD_QEMU_IMG create -b ${CF_VM_IMG_LST[$_idx]} -f qcow2 $_qcow_file" "$FUNCNAME" 1>/dev/null
    if [[ "${CF_VM_E_IMG_LST[$_idx]}" ]];then
        _qcow_file="$CF_QCOW_HOME/"`basename ${CF_VM_E_IMG_LST[$_idx]}`".qcow.""$_idx"
        rm -rf $_qcow_file
        func_tool_cmd_run_pass "$CF_CMD_QEMU_IMG create -b ${CF_VM_E_IMG_LST[$_idx]} -f qcow2 $_qcow_file" "$FUNCNAME" 1>/dev/null
    fi
}

func_run_create_all_qcow()
{
    local _idx=0
    local _count=${#OS_RUN_NAME_LST[*]}
    mkdir -p $CF_QCOW_HOME
    while [ $_idx -lt $_count ];
    do
        echo "$FUNCNAME: create qcow file for ${OS_RUN_NAME_LST[$_idx]} at $CF_QCOW_HOME"
        func_run_rebuild_qcow $_idx
        _idx=`expr $_idx + 1`
    done
}

func_run_create_all_guest()
{
    local _hvm _idx=0 _count=${#OS_RUN_NAME_LST[*]}
    while [ $_idx -lt $_count ];
    do
        echo "$FUNCNAME: ($_idx/$_count)Create Guest for ${OS_RUN_NAME_LST[$_idx]}"
        func_vm_start $_idx
        _idx=`expr $_idx + 1`
    done
}

func_run_update_all_info()
{
    # loop to make sure each guest already have been created
    # for guest id ( VM create success )
    local _loop_count=100 _idx=0 _count
    while [ true  ];
    do
        echo "$FUNCNAME: ($_idx/$_loop_count)catch id for Guest"
        func_vm_refresh_all_id
        sleep $TIME_FW_WAIT
        _count=`echo ${OS_RUN_ID_LST[*]}|sed 's/  //g'|sed 's/ /\n/g' |sort|uniq|wc -l`
        [[ $_count -eq ${#OS_RUN_NAME_LST[*]} ]] && break
        [[ $_idx -eq $_loop_count ]] && echo "In $FUNCNAME id detect error, current effective id count: $_count" && func_tool_exit_status "$FUNCNAME" $ERR_LV_ERR
        _idx=`expr $_idx + 1`
    done

    # for guest ip
    _idx=0
    while [ true ];
    do
        echo "$FUNCNAME: ($_idx/$_loop_count)catch ip for Guest"
        func_vm_refresh_all_ip
        sleep $TIME_FW_WAIT
        _count=`echo ${OS_RUN_IP_LST[*]}|sed 's/  //g'|sed 's/ /\n/g' |sort|uniq|wc -l`
        [[ $_count -eq ${#OS_RUN_MAC_LST[*]} ]] && [[ `echo ${OS_RUN_IP_LST[*]}` ]] && break
        [[ $_idx -eq $_loop_count ]] && echo "In $FUNCNAME ip detect error, current effective ip count: $_count" && func_tool_exit_status "$FUNCNAME" $ERR_LV_ERR
        _idx=`expr $_idx + 1`
    done

    # for guest boot finish
    _idx=0; _loop_count=200
    while [ true ];
    do
        echo "$FUNCNAME: ($_idx/$_loop_count)detect alive for Guest"
        sleep $TIME_FW_WAIT
        _count=`func_vm_detect_all_alive`
        [[ ! "$_count" ]] && break
        [[ $_idx -eq $_loop_count ]] && echo "In $FUNCNAME detect vm alive failed, no response ip list: $_count" && func_tool_exit_status "$FUNCNAME" $ERR_LV_ERR
        _idx=`expr $_idx + 1`
    done
}

func_run_workload()
{
    local _idx="$1" _cmd _time _log_path="$OS_RUN_LOG_PATH/workload/store/${OS_RUN_NAME_LST[$_idx]}"
    local _tmp_ps=$FW_TMP_FOLDER/$FUNCNAME.ps.$RANDOM
    local _log_file="$OS_RUN_LOG_PATH/workload/${OS_RUN_NAME_LST[$_idx]}" _log_store
    [[ $CF_STORE_WORKLOAD -eq 1 ]] && mkdir -p $_log_path
    while [ true ];
    do
        ps -ef > $_tmp_ps
        func_vm_status $_idx
        # skip p&d status
        [[ `echo ${OS_RUN_STATUS_LST[$_idx]}|grep '[pd]'` ]] && sleep $TIME_STAF_WAIT && continue
        for _cmd in `echo ${OS_RUN_WORK_LST[$_idx]}`;
        do
            _time=`func_tool_get_time`
            # check pid process already exist
            [[ `grep "${OS_RUN_IP_LST[$_idx]}" $_tmp_ps|grep "$_cmd"` ]] && continue
            [[ $CF_STORE_WORKLOAD -eq 1 ]] && _log_store=$_log_path/$_time || _log_store=/dev/null
            # workload log record
            echo -ne "$_time\t${OS_RUN_IP_LST[$_idx]}\t${OS_RUN_WTYPE_LST[$_idx]}\t" >> $_log_file
            # Workload Order: Linux Shell/Linux Binary/Windows BAT
            if [[ -f "$CF_WORK_HOME/$_cmd.sh" ]];then # Linux Shell
                _cmd="$CF_WORK_HOME/$_cmd.sh ${OS_RUN_IP_LST[$_idx]}"
            elif [[ -f "$CF_WORK_HOME/$_cmd" ]];then # Linux Binary/Shell etc
                _cmd="$CF_WORK_HOME/$_cmd ${OS_RUN_IP_LST[$_idx]}"
            else    # Windows BAT
                # free staf process list
                $CMD_STAF ${OS_RUN_IP_LST[$_idx]} process free all
                _cmd="$CMD_STAF ${OS_RUN_IP_LST[$_idx]} process start command c:\\$FW_CASE_NAME\\$_cmd.bat wait returnstdout"
            fi
            # run workload
            echo "$_cmd" >> $_log_file
            [[ "$CF_STORE_WORKLOAD" -eq 1 ]] && echo "$_cmd" >> $_log_store
            [[ "${OS_RUN_WTYPE_LST[$_idx]}" -eq 0 ]] && $_cmd 2>&1 >> $_log_store
            [[ "${OS_RUN_WTYPE_LST[$_idx]}" -eq 1 ]] && $_cmd 2>&1 >> $_log_store &
        done
        sleep $TIME_STAF_WAIT
        func_vm_status $_idx
        # skip p&d empty status
        [[ `echo ${OS_RUN_STATUS_LST[$_idx]}|grep '[pd]'` ]] && sleep $TIME_STAF_WAIT && continue
        func_vm_detect_alive $_idx
        [[ $? -ne 0 ]] && break
        # main process exist
        [[ ! `cat $_tmp_ps|awk '{print $2;}'|grep "$FW_PID"` ]] && break
    done
    local _id
    # stop child process
    for _cmd in `echo ${OS_RUN_WORK_LST[$_idx]}`;
    do
        ps -ef > $_tmp_ps
        for _id in `grep "${OS_RUN_IP_LST[$_idx]}" $_tmp_ps|grep "$_cmd"|awk '{print $2;}'`;
        do
            func_tool_kill_pid $_id $FUNCNAME
        done
    done
    rm -rf $_tmp_ps
    _time=`func_tool_get_time`
    echo -e "$_time\t${OS_RUN_IP_LST[$_idx]}\tquit\t$FUNCNAME" >> $_log_file
    func_tool_exit_status "Child PID $FUNCNAME" $ERR_LV_CHILD
}

func_run_all_workload()
{
    mkdir -p $OS_RUN_LOG_PATH/workload
    local _idx=0 _count="${#OS_RUN_NAME_LST[*]}"
    while [ $_idx -lt $_count ];
    do
        echo "Start workload for ${OS_RUN_NAME_LST[$_idx]}"
        echo -e "time\t\tip address\ttype\tcmd" > "$OS_RUN_LOG_PATH/workload/${OS_RUN_NAME_LST[$_idx]}"
        [[ `echo ${OS_RUN_WORK_LST[$_idx]}` ]] && func_run_workload $_idx &
        _idx=`expr $_idx + 1`
    done
}

func_run_execute()
{
    local _cmd _tmp_ps=$FW_TMP_FOLDER/$FUNCNAME.ps.$RANDOM
    [[ ! `echo ${CF_EXEC_LST[*]}` ]] && echo "No host execute need to run" && func_tool_exit_status "Child PID $FUNCNAME" $ERR_LV_PASS
    while [ true ];
    do
        ps -ef > $_tmp_ps
        for _cmd in ${CF_EXEC_LST[*]};
        do
            $_cmd
            sleep $TIME_FW_WAIT
        done
        sleep $TIME_FW_WAIT
        # main process exist
        [[ ! `cat $_tmp_ps|awk '{print $2;}'|grep "$FW_PID"` ]] && break
    done
    rm $_tmp_ps
    func_tool_exit_status "Child PID $FUNCNAME" $ERR_LV_CHILD
}

func_run_recover()
{
    local _end_time=$1 _time _idx
    while [ true ]
    do
        _time=`date +%s`
        [[ $_time -gt $_end_time ]] && break
        # deal with reboot vm/not alive VM
        for _idx in `func_vm_detect_all_alive`;
        do
            _time=`date +%s`
            func_vm_status $_idx
            # p:paused d:dying -:empty
            [[ `echo ${OS_RUN_STATUS_LST[$_idx]}|grep '[pd]'` ]] && continue
            func_case_guest_recover $_idx $_time
        done
        sleep $TIME_FW_WAIT
    done
}

#################################################################
##
## run case process
## function flag: func_case
##
#################################################################
func_case_time_tag()
{
    local _time=`expr $2 - $1`
    local _s_time=`func_tool_convert_utc_time $1` _log="$OS_RUN_LOG_PATH/run_status" _tmp_file=$FW_TMP_FOLDER/run_status.$RANDOM

    echo "Start from $_s_time" > $_tmp_file
    echo "Run Time" >> $_tmp_file
    echo "day: "`expr $_time / 86400` >> $_tmp_file
    _time=`expr $_time % 86400`
    echo "hour: "`expr $_time / 3600` >> $_tmp_file
    _time=`expr $_time % 3600`
    echo "minute: "`expr $_time / 60` >> $_tmp_file
    _time=`expr $_time % 60`
    echo "second: "`expr $_time` >> $_tmp_file
    mv $_tmp_file $_log
}

func_case_run_process()
{
    # set log collect path: date format: ww"week"_0"day in week"
    func_run_all_workload
    func_run_execute &
    local _time=`date +%s` _time_unit _idx
    local _s_time_s=$_time _end_time
    echo "$FW_CASE_NAME test framework start at: "`func_tool_convert_utc_time $_time`
    case "$CF_TIME_UNIT" in
        "s")    _time_unit=1  ;;
        "m")    _time_unit=60 ;;
        "h")    _time_unit=3600 ;;
        "d")    _time_unit=86400 ;;
        *)      func_tool_exit_status "$FUNCNAME" $ENV_LV_PARA
    esac
    _end_time=$((($CF_TIME_RUN * $_time_unit) + $_time))

    func_run_recover $_end_time &

    while [ true ];
    do
        sleep $TIME_SCAN_WAIT
        _time=`date +%s`
        func_case_record_error_log $_time
        func_case_time_tag $_s_time_s $_time
        # time meet the target quit the loop
        [[ $_time -gt $_end_time ]] && break
    done
}

func_case_guest_recover()
{
    local _idx="$1" _time=`func_tool_convert_utc_time $2`
    # destroy guest
    local _id=`func_vm_covert_name_to_id ${OS_RUN_NAME_LST[$_idx]}`
    [[ "$_id" ]] && \
        func_tool_cmd_loop_pass "$CMD_XL_DESTROY $_id" "$FUNCNAME" && \
        sleep $TIME_XL_WAIT
    # backup error qcow file
    func_run_backup_qcow $_idx $_time
    # rebuild qcow file
    func_run_rebuild_qcow $_idx

    # clear blocked process child pid
    for _id in `ps -ef |grep "${OS_RUN_IP_LST[$_idx]}"|grep -v 'ps'|awk '{print $2;}'|grep -v $$`;
    do
        func_tool_kill_pid $_id $FUNCNAME
    done
    # boot guest
    func_vm_start $_idx

    func_case_recover_workload $_idx $_time
}

func_case_recover_workload()
{
    local _idx="$1"  _time="$2"
    local _i=0 _loop_count=100
    while [ $_i -lt $_loop_count ];
    do
        ping ${OS_RUN_IP_LST[$_idx]} -c 2 2>&1 >/dev/null
        [[ $? -eq 0 ]] && break
        sleep $TIME_FW_WAIT
        _i=`expr $_i + 1`
    done
    [[ $_i -ge $_loop_count ]] && func_tool_exit_status "Ping failed Child PID $FUNCNAME" $ERR_LV_UNKNOW
    _i=0
    while [ $_i -lt $_loop_count ];
    do
        func_vm_detect_alive $_idx
        [[ $? -eq 0 ]] && break
        sleep $TIME_FW_WAIT
        _i=`expr $_i + 1`
    done
    [[ $_i -ge $_loop_count ]] && func_tool_exit_status "Alive error Child PID $FUNCNAME" $ERR_LV_ERR

    echo -e "$_time\t${OS_RUN_IP_LST[$_idx]}\tCreate VM again" >> "$OS_RUN_LOG_PATH/workload/${OS_RUN_NAME_LST[$_idx]}"
    echo -e `func_tool_get_time`"\t${OS_RUN_IP_LST[$_idx]}\tCase recover" >> "$OS_RUN_LOG_PATH/workload/${OS_RUN_NAME_LST[$_idx]}"
    [[ `echo ${OS_RUN_WORK_LST[$_idx]}` ]] && func_run_workload $_idx &
}

func_case_record_error_log()
{
    local _log_path=$OS_RUN_LOG_PATH _cur_name_flag=`func_tool_convert_utc_time $1` _mk_collect=0
    local _f_tmp=$FW_TMP_FOLDER/error_log.$RANDOM

    _func_catch_error()
    {
        local _error=0 _file="$1" _type="$2"
        shift 2
        while [ $# -ne 0 ]
        do
            # using param as grep param
            [[ `grep "$1" $_file` ]] && _error=1 && break
            shift
        done
        # keyword match create file
        [[ $_error -eq 0 ]] && return 0
        local _per_file=`ls -c $_log_path/$_type/`
        _per_file="$_log_path/$_type/"`echo $_per_file|awk '{print $1;}'|sed '2,$d'`
        [[ "$_per_file" = "$_log_path/$_type/" ]] && cp "$_file" "$_log_path/$_type/$_cur_name_flag" && return 1
        diff -r $_file $_per_file >/dev/null
        [[ $? -eq 1 ]] && cp "$_file" "$_log_path/$_type/$_cur_name_flag" && return 1

        return 0
    }

    # Catch log by dmesg
    mkdir -p $_log_path/dmesg
    dmesg -c > $_f_tmp
    _func_catch_error $_f_tmp 'dmesg' 'gfx reset' 'Call Trace' '*ERROR*' 'vGT error' 'privcmd_fault' 'Context Descriptor'
    [[ $? -ne 0 ]] && _mk_collect=1

    # Catch log from syslog
    mkdir -p $_log_path/syslog
    grep -v 'kernel: ' /var/log/syslog |tail -n 100 > $_f_tmp
    _func_catch_error $_f_tmp 'syslog' 'gfx reset' 'Call Trace' '*ERROR*' 'vGT error' 'privcmd_fault' 'Context Descriptor' ' hang '
    [[ $? -ne 0 ]] && _mk_collect=1

    # Catch log from kernel log
    #mkdir -p $_log_path/kern
    #grep -v 'vGT info' /var/log/kern.log |grep -v 'vGT warning'|tail -n 100 > $_f_tmp
    #_func_catch_error $_f_tmp 'kern' 'gfx reset' 'Call Trace' '*ERROR*' 'vGT error' 'privcmd_fault' 'Context Descriptor' 'hang'
    #[[ $? -ne 0 ]] && _mk_collect=1

    # Catch log by xl dmesg
    mkdir -p $_log_path/xldmesg
    xl dmesg -c > $_f_tmp
    _func_catch_error $_f_tmp 'xldmesg' 'Call Trace'
    [[ $? -ne 0 ]] && _mk_collect=1

    # check Xorg catch Error information
    if [ $FETCH_XORG -eq 1 ];then
        mkdir -p $_log_path/xorg
        tail -n 500 "/var/log/Xorg.0.log" > $_f_tmp
        _func_catch_error $_f_tmp 'xorg' '] (EE)'
    fi

    rm -rf $_f_tmp

    #######################
    #######################
    # check guest os status
    local _vm_path=$FW_TMP_FOLDER/check_vm/$_cur_name_flag i
    mkdir -p $_vm_path
    mkdir -p $_log_path/check_vm

    local _vm_error=0
    # detect vm id change which means vm already reboot
    func_vm_refresh_all_id > $_f_tmp
    [[ `grep ' CHANGE ' $_f_tmp` ]] && mv $_f_tmp "$_vm_path/vm_id" && _vm_error=1

    # detect current all vm is alive status
    > $_f_tmp
    for i in `func_vm_detect_all_alive`;
    do
        func_vm_status $i
        # skip p&d empty status
        #[[ `echo ${OS_RUN_STATUS_LST[$i]}|grep '[pd]'` ]] && sleep $TIME_STAF_WAIT && continue
        echo "VM name: ${OS_RUN_NAME_LST[$i]}" >> $_f_tmp
        echo "VM status: ${OS_RUN_STATUS_LST[$i]}" >> $_f_tmp
        echo "HVM : $CF_HVM_HOME/""${OS_RUN_NAME_LST[$i]}"".hvm" >> $_f_tmp
        echo "VM id: ${OS_RUN_ID_LST[$i]}" >> $_f_tmp
        echo "VM ip: ${OS_RUN_IP_LST[$i]}" >> $_f_tmp
        echo >> $_f_tmp
    done
    [[ `grep 'VM' $_f_tmp` ]] && mv $_f_tmp "$_vm_path/alive" && _vm_error=1

    # check qemu file by 'reason code' => reboot etc 'Issued' => BSOD etc
    mkdir -p $_vm_path/xen
    for i in ${OS_RUN_NAME_LST[*]}
    do
        [[ `grep 'reason code' $XEN_LOG_PATH/xl-$i.log` ]] && cp $XEN_LOG_PATH/xl-$i.log "$_vm_path/xen" && _vm_error=1
        [[ `grep 'Issued' $XEN_LOG_PATH/qemu-dm-$i.log` ]] && cp $XEN_LOG_PATH/qemu-dm-$i.log "$_vm_path/xen" && _vm_error=1
    done

    # Compare with per-check guest log
    if [[ "$_vm_error" -eq 1 ]];then
        _mk_collect=1
        local _per_check=`ls -c $_log_path/check_vm/`
        _per_check="$_log_path/check_vm/"`echo $_per_check|awk '{print $1;}'|sed '2,$d'`
        if [[ "$_per_check" = "$_log_path/check_vm/" ]];then
            cp "$_vm_path" "$_log_path/check_vm/$_cur_name_flag" -rf
        else
            diff -r "$_vm_path" "$_per_check" >/dev/null
            [[ $? -eq 1 ]] && cp "$_vm_path" "$_log_path/check_vm/$_cur_name_flag" -rf
        fi
    fi
    rm -rf $_vm_path

    if [ $_mk_collect -eq 1 ];then
        mkdir -p "$_log_path/error/$_cur_name_flag"
        _func_copy()
        {
            [[ ! -e $_log_path/$1/$_cur_name_flag ]] && return
            [[ ! -e "$_log_path/error/$_cur_name_flag/$1" ]] && ln -s "$_log_path/$1/$_cur_name_flag" "$_log_path/error/$_cur_name_flag/$1"
        }
        _func_copy dmesg
        _func_copy xldmesg
        _func_copy check_vm
        _func_copy syslog
        _func_copy kern
        [[ $FETCH_XORG -eq 1 ]] && _func_copy xorg
        [[ `ls "$_log_path/error/$_cur_name_flag"|wc -l` -eq 0 ]] && rm -rf "$_log_path/error/$_cur_name_flag"
    fi
}
#################################################################
##
## run order
##
#################################################################

# 1. parameter
func_opt_parse_option $@

# 2. check environment
func_mtbf_env_check

# 3. create example configure file
if [ ! -f "$FW_CONF_FILE" ];then
    func_conf_create
    echo "$FW_CONF_FILE already be created"
    func_tool_exit_status "$FUNCNAME" $ERR_LV_ENV
fi

# 4. load configure file
func_conf_load

# 5. create folder for mtbf using
for i in `echo $CF_FOLD_ALL`;
do
    mkdir -p $i
    [[ ! -d $i ]] && echo "Detect $i should be a folder, please check it." && func_tool_exit_status "$FUNCNAME" $ERR_LV_ENV
done

# 6. deal with parameter
[[ $OPT_ENV_INIT -eq 1 ]] && func_mtbf_env_init && ret=1
[[ $OPT_CONF_DUMP -eq 1 ]] && echo "check $FW_CONF_FILE & dump it" && func_conf_dump && ret=1
[[ $OPT_ENV_UPDATE -eq 1 ]] && func_img_update && ret=1
[[ $ret -eq 1 ]] && func_tool_exit_status "$FW_CASE_NAME" $ERR_LV_PASS

# release useless var
unset CF_DEF_LST CF_GLOBAL_LST
# setup store log path:
OS_RUN_LOG_PATH="$CF_LOG_HOME/$CF_CASE""_ww"`date +%V_0%u`

# 7. create run time environment
func_run_create_all_qcow
func_run_create_all_hvm
func_run_create_all_guest
sleep $TIME_FW_WAIT
func_run_update_all_info

# 8. start time calculator
func_case_run_process

# 9. clear environment
func_mtbf_env_clear

func_tool_exit_status "$FW_CASE_NAME" $ERR_LV_PASS

