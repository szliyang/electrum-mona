#!/bin/bash

PYTHON_VERSION=3.6.3
# Please update these links carefully, some versions won't work under Wine
PYTHON_URL=https://www.python.org/ftp/python/$PYTHON_VERSION/python-$PYTHON_VERSION.exe
PYTHON_SHA256=cb3bfe1e6b0d1254cebf9bb1fc095fe74396af8baf65f244d5f9b349d232b280
NSIS_URL=http://prdownloads.sourceforge.net/nsis/nsis-3.02.1-setup.exe?download
NSIS_SHA256=736c9062a02e297e335f82252e648a883171c98e0d5120439f538c81d429552e
VC2015_URL=https://download.microsoft.com/download/9/3/F/93FCF1E7-E6A4-478B-96E7-D4B285925B00/vc_redist.x86.exe
WINETRICKS_MASTER_URL=https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
LYRA2RE_HASH_PYTHON_URL=https://github.com/metalicjames/lyra2re-hash-python/archive/master.zip

## These settings probably don't need change
export WINEPREFIX=/opt/wine64
#export WINEARCH='win32'

PYHOME=c:/python$PYTHON_VERSION
PYTHON="wine $PYHOME/python.exe -OO -B"


verify_hash() {
    local file=$1 expected_hash=$2 out=
    actual_hash=$(sha256sum $file | awk '{print $1}')
    if [ "$actual_hash" == "$expected_hash" ]; then
        return 0
    else
        echo "$file $actual_hash (unexpected hash)" >&2
        exit 0
    fi
}

# Let's begin!
cd `dirname $0`
set -e

# Clean up Wine environment
echo "Cleaning $WINEPREFIX"
rm -rf $WINEPREFIX
echo "done"

wine 'wineboot'

echo "Cleaning tmp"
rm -rf tmp
mkdir -p tmp
echo "done"

cd tmp

# Install Python
wget -O python$PYTHON_VERSION.exe "$PYTHON_URL"
verify_hash python$PYTHON_VERSION.exe $PYTHON_SHA256
wine python$PYTHON_VERSION.exe /quiet TargetDir=C:\python$PYTHON_VERSION

# upgrade pip
$PYTHON -m pip install pip --upgrade

# Install PyWin32
$PYTHON -m pip install pypiwin32

# Install PyQt
$PYTHON -m pip install PyQt5

## Install pyinstaller
$PYTHON -m pip install pyinstaller==3.3


# Install ZBar
#wget -q -O zbar.exe "https://sourceforge.net/projects/zbar/files/zbar/0.10/zbar-0.10-setup.exe/download"
#wine zbar.exe

# install Cryptodome
$PYTHON -m pip install pycryptodomex

# install PySocks
$PYTHON -m pip install win_inet_pton

# install websocket (python2)
$PYTHON -m pip install websocket-client

# Upgrade setuptools (so Electrum can be installed later)
$PYTHON -m pip install setuptools --upgrade

# install cython
$PYTHON -m pip install cython

# Install NSIS installer
wget -q -O nsis.exe "$NSIS_URL"
verify_hash nsis.exe $NSIS_SHA256
wine nsis.exe /S

# Install UPX
#wget -O upx.zip "https://downloads.sourceforge.net/project/upx/upx/3.08/upx308w.zip"
#unzip -o upx.zip
#cp upx*/upx.exe .

# add dlls needed for pyinstaller:
cp $WINEPREFIX/drive_c/python$PYTHON_VERSION/Lib/site-packages/PyQt5/Qt/bin/* $WINEPREFIX/drive_c/python$PYTHON_VERSION/

# Install MinGW
wget http://downloads.sourceforge.net/project/mingw/Installer/mingw-get-setup.exe
wine mingw-get-setup.exe

echo "add C:\MinGW\bin to PATH using regedit"
echo "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
#regedit
wine reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH /t REG_EXPAND_SZ /d C:\\MinGW\\bin\;C\:\\windows\\system32\;C:\\windows\;C:\\windows\\system32\\wbem /f

wine mingw-get install gcc
wine mingw-get install mingw-utils
wine mingw-get install mingw32-libz

printf "[build]\ncompiler=mingw32\n" > $WINEPREFIX/drive_c/python$PYTHON_VERSION/Lib/distutils/distutils.cfg

# Install VC++2015
#wget -O vc_redist.x86.exe "$VC2015_URL"
#wine vc_redist.x86.exe /quiet
wget $WINETRICKS_MASTER_URL
bash winetricks vcrun2015

# build msvcr140.dll
cp ../msvcr140.patch $WINEPREFIX/drive_c/python$PYTHON_VERSION/Lib/distutils
pushd $WINEPREFIX/drive_c/python$PYTHON_VERSION/Lib/distutils
patch < msvcr140.patch
popd

wine pexports $WINEPREFIX/drive_c/python$PYTHON_VERSION/vcruntime140.dll >vcruntime140.def
wine dlltool -dllname $WINEPREFIX/drive_c/python$PYTHON_VERSION/vcruntime140.dll --def vcruntime140.def --output-lib libvcruntime140.a
cp libvcruntime140.a $WINEPREFIX/drive_c/MinGW/lib/

# install lyra2re2_hash
$PYTHON -m pip install $LYRA2RE_HASH_PYTHON_URL

#echo "Wine is configured. Please run prepare-pyinstaller.sh"
