#!/bin/bash

## IMPORTANT
## This is a `bash` script, don't use it with `sh`.
## it is a single filer and intend to be simple

## the dir where everything will be installed
__nixstall_dir="${HOME}/.nixstall"

## url from where to get latest nixstall, if required
#__nixstall_url="https://raw.github.com/kdabir/nixstall/master/bin/nixstall.sh"
__nixstall_url="http://git.io/nixstall"

# where nixstall itself will be installed
__nixstall_home="${__nixstall_dir}/nixstall"
__nixstall_bin="${__nixstall_home}/bin"
__nixstall_script="${__nixstall_bin}/nixstall"
__nixstall_version="0.1"

if [[ "$#" == "0" ]]; then
    # when called with no arguments, we are in init/source mode!
    # if this is executed in new shell, it should not have any effect

    export _NIXSTALL_PATHS=""
    ## add some functions to current shell may be
    function nixstall_reload() {
        for dir in $(find -L ${__nixstall_dir} -maxdepth 2 -type d -name bin); do
            _NIXSTALL_PATHS="${_NIXSTALL_PATHS:+"$_NIXSTALL_PATHS:"}$dir"

            # http://superuser.com/a/39995/66921
             if [ -d "$dir" ] && [[ ":$PATH:" != *":$dir:"* ]]; then
                PATH="${PATH:+"$PATH:"}$dir"
            fi
        done
    }

    function nixstall_link() {
        if [[ "$#" == "0" ]]; then
            ln -s $(pwd) $__nixstall_dir
        else
            ln -s $1 $__nixstall_dir
        fi
    }

    function nixstall_list() {
        while read line
        do 
            # Show also actual file path of a symbolic link
            if [ `echo ${line} | egrep "@$"` ]; then
                echo -n "${line%@} -> "
                readlink -e -q $__nixstall_dir/${line%@}
            else
                echo $line
            fi
        done < <(\ls -F -1 $__nixstall_dir)
    }

    function nixstall_remove() {
        if [[ "$#" == "1" ]] && [ -e "$__nixstall_dir/$1" ]; then
            if [ "`readlink -e $__nixstall_dir/$1`" == "`readlink -e $__nixstall_home`" ]; then
                echo "Unable to execute \"nixstall_remove $1\" as it's nixstall itself"
                echo "Remove $__nixstall_dir manually to uninstall nixstall"
            else
                echo "removing $__nixstall_dir/$1"
                rm -I -v -r $__nixstall_dir/$1
            fi
        else
            echo "Specify one of installed apps under $__nixstall_dir:"
            \ls -1 $__nixstall_dir
        fi
    }

    # reload only nixstall dir exists, otherwise find will fail
    [ -d "$__nixstall_dir" ] && nixstall_reload

else
    ## this will execute when nixstall is called with some params

    ## if user explicitly aksed or if the nixstall script is not present locally
    if [ "$1" == "self" ] || [ ! -s $__nixstall_script ];then

        ## if nixstall's bin is not present
        if [ ! -d "$__nixstall_bin" ]; then
            echo "*** creating nixstall directory at: $__nixstall_dir ***"
            # create it
            mkdir -p $__nixstall_bin
        fi

        # take a backup only if the script already exists
        # because curl might fail and write grabage/blank to the script
        # this way user will be able to recover nixstall
        [ -s $__nixstall_script ] && cp $__nixstall_script "/tmp/nixstall_bak.sh"

        # Download the nixstall script
        curl -sL "$__nixstall_url" > $__nixstall_script

        # make nixstall executable
        chmod +x "$__nixstall_script"

        bash_profile_file="${HOME}/.bash_profile"
        zshrc_file="${HOME}/.zshrc"
        profile_file="${HOME}/.profile"
        bashrc_file="${HOME}/.bashrc"

        if [ -z "$_NIXSTALL_PATHS" ]; then

            ## currently only updating two files
            for file in $bash_profile_file $zshrc_file; do

                ## check for existance of this line already
                ## this will match even in comments, which is okay because if its commented, probably user has deliberately done so
                if ! grep -q $__nixstall_script $file; then
                    echo "updating $file"
                    echo -e "\n# Added by nixstall, don't remove unless you know what you are doing" >> $file
                    echo -e "[[ -s \"${__nixstall_script}\" ]] && source \"${__nixstall_script}\"\n" >> $file
                fi
            done
        fi

        ## if only self was to be installed, we are done and exit now
        if [ "$1" == "self" ]; then
            echo "You may need to open a new terminal for changes to reflect!"
            exit 0
        fi
    fi

    function extract_archive() {
        # Check mime-type of the arichive file
        FILE_MIME_TYPE=`file --mime-type $1`

        if [[ `echo $FILE_MIME_TYPE | egrep "application/zip"` ]] ; then
            # application/zip : .zip

            # Validate archive file has right directory strucutre, i.e. it contains `bin`
            if [[ `unzip -l $1 | awk -F'/' '{print $2}' | egrep "bin"` ]] ; then
                unzip -d $__nixstall_dir -o $1
            else
                echo "Invalid archive file: $1 does not have right directory strucutre, i.e. it does not contain \"bin\""
            fi

        elif [[ `echo $FILE_MIME_TYPE | egrep "application/x-(tar)|(gzip)|(bzip2)|(xz)"` ]] ; then
            # application/x-tar : .tar
            # application/x-gzip : .gz
            # application/x-bzip2 : .bz2
            # application/x-xz : .xz
            # recent tar can handle tar.gz, tar.bz2 and tar.xz without the options -z/--gzip, -j/--bzip2 and -J/--xz
            # Note that just .gz, bz2,.xz archives cannot be extracted by this command

            # Validate archive file has right directory strucutre, i.e. it contains `bin`
            if [[ `tar tf $1 | awk -F'/' '{print $2}' | egrep "bin"` ]] ; then
                tar xvf $1 -C $__nixstall_dir
            else
                echo "Invalid archive file: $1 does not have right directory strucutre, i.e. it does not contain \"bin\""
            fi

        else
            echo "Invalid archive file: $1 is not supported, currently supporting .zip, .tar.gz, tar.bz2 and tar.xz only"
        fi
    }

    ## we have to download the archive
    if [ "$1" == "get" ] && [ $# -ge 2 ] ; then
        URL_LIST=${@:2}
        TMP_DIR=`mktemp -d "/tmp/${0##*/}.tmpdir.XXXXXX"`
        pushd "$TMP_DIR"
        for _url in $URL_LIST ; do
            echo "Start downloading from $_url"
            curl -L -O "$_url"
        done
        for _file in * ; do
            echo "Start extracting $_file"
            extract_archive $_file
        done
        popd
        echo "\n All archive files downloaded under $TMP_DIR , copy it if you want to save it"

    elif [ -s "$1" ];then
        echo "Start extracting $1"
        extract_archive $1
    else
        echo "not a valid usage"
        exit 1
    fi

    # TODO checking existance of variables from sourced script seems to be flawed
    # need to fix that
    if type nixstall_reload > /dev/null 2>&1; then
        echo -e "\nPlease close this terminal session and open a new one or use 'nixstall_reload'"
    else
        echo -e "\nPLEASE CLOSE THIS TERMINAL SESSION AND OPEN A NEW ONE"
    fi

fi
