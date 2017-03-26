#!/bin/sh

# Regression testing script for MicroC
# Step through a list of files
#  Compile, run, and check the output of each expected-to-work test
#  Compile and check the error of each expected-to-fail test

# Path to the LLVM interpreter
LLI="lli"
#LLI="/usr/local/opt/llvm/bin/lli"

# Path to the LLVM compiler
LLC="llc"

# Path to the C compiler
CC="gcc"

# Path to the microc compiler.  Usually "./microc.native"
# Try "_build/microc.native" if ocamlbuild was unable to create a symbolic link.
DECAF="./decaf.native"
#DECAF="_build/decaf.native"

file_ext="dcf"

# Set time limit for all operations
ulimit -t 30

globallog=testall.log
rm -f $globallog
error=0
globalerror=0

keep=0

Usage() {
    echo "Usage: testall.sh [options] [.${file_ext} files]"
    echo "-k    Keep intermediate files"
    echo "-h    Print this help"
    exit 1
}

SignalError() {
    if [ $error -eq 0 ] ; then
	echo "FAILED"
	error=1
    fi
    echo "  $1"
}

# Compare <outfile> <reffile> <difffile>
# Compares the outfile with reffile.  Differences, if any, written to difffile
Compare() {
    generatedfiles="$generatedfiles $3"
    echo diff -b $1 $2 ">" $3 1>&2
    diff -b "$1" "$2" > "$3" 2>&1 || {
	SignalError "$1 differs"
	echo "FAILED $1 differs from $2" 1>&2
    }
}

# Run <args>
# Report the command, run it, and report any errors
Run() {
    echo $* 1>&2
    eval $* || {
	SignalError "$1 failed on $*"
	return 1
    }
}

# RunFail <args>
# Report the command, run it, and expect an error
RunFail() {
    echo $* 1>&2
    eval $* && {
	SignalError "failed: $* did not report an error"
	return 1
    }
    return 0
}

Check() {
    error=0
    basename=$(echo $1 | sed 's/.${file_ext}//' | cut -f 1 -d '.')
    reffile=$(echo $1 | sed 's/.${file_ext}$//')
    basedir="`echo $1 | sed 's/\/[^\/]*$//'`/."

    echo -n "${basename}..."

    echo 1>&2
    echo "###### Testing ${basename}" 1>&2

    generatedfiles=""

    generatedfiles="${generatedfiles} ${basename}.ll ${basename}.s ${basename} ${basename}.out" &&
    Run "${DECAF} -l" "<" $1 "| tail -n+3" ">" "${basename}.ll" &&
    Run "${LLC}" "${basename}.ll" ">" "${basename}.s" &&
    Run "${CC}" "-o" "${basename}" "${basename}.s" &&
    Run "./${basename}" ">" "${basename}.out" &&
    Compare ${basename}.cmp ${basename}.out ${basename}.diff

    # Report the status and clean up the generated files

    if [ $error -eq 0 ] ; then
	if [ $keep -eq 0 ] ; then
	    rm -f $generatedfiles
	fi
	echo "OK"
	echo "###### SUCCESS" 1>&2
    else
	echo "###### FAILED" 1>&2
	globalerror=${error}
    fi
}

CheckFail() {
    error=0
    basename=$(echo $1 | sed 's/.${file_ext}//' | cut -f 1 -d '.')
    reffile=`echo $1 | sed 's/.${file_ext}$//'`
    basedir="`echo $1 | sed 's/\/[^\/]*$//'`/."

    echo -n "${basename}..."

    echo 1>&2
    echo "###### Testing ${basename}" 1>&2

    generatedfiles=""

    generatedfiles="${generatedfiles} ${basename}.out ${basename}.diff" &&
    RunFail "${DECAF}" "<" $1 "2>" "${basename}.out" ">>" ${globallog} &&
    Compare ${basename}.cmp ${basename}.out ${basename}.diff

    # Report the status and clean up the generated files

    if [ $error -eq 0 ] ; then
	if [ $keep -eq 0 ] ; then
	    rm -f $generatedfiles
	fi
	echo "OK"
	echo "###### SUCCESS" 1>&2
    else
	echo "###### FAILED" 1>&2
	globalerror=$error
    fi
}

while getopts kdpsh c; do
    case $c in
	k) # Keep intermediate files
	    keep=1
	    ;;
	h) # Help
	    Usage
	    ;;
    esac
done

shift `expr $OPTIND - 1`

LLIFail() {
  echo "Could not find the LLVM interpreter \"$LLI\"."
  echo "Check your LLVM installation and/or modify the LLI variable in testall.sh"
  exit 1
}

which "$LLI" >> $globallog || LLIFail

if [ $# -ge 1 ]
then
    files=$@
else
	# TODO: Uncomment this when fail tests ae put in
    files="tests/test_*.${file_ext}"
fi

for file in $files
do
    case $file in
	*test_*)
	    Check $file 2>> $globallog
	    ;;
	*fail_*)
	    CheckFail $file 2>> $globallog
	    ;;
	*)
	    echo "unknown file type $file"
	    globalerror=1
	    ;;
    esac
done

exit $globalerror