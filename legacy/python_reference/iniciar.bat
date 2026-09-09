@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

title Timesheet Banco de Horas

echo.
echo  Timesheet Banco de Horas - iniciando...
echo.

where python >nul 2>&1
if errorlevel 1 goto :python_missing

python -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)" >nul 2>&1
if errorlevel 1 goto :python_old

if not exist ".venv\Scripts\python.exe" (
    echo Criando ambiente virtual...
    python -m venv .venv || goto :error
)

".venv\Scripts\python.exe" -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)" >nul 2>&1
if errorlevel 1 (
    echo [ERRO] O ambiente .venv foi criado com Python antigo ou esta corrompido.
    echo Apague a pasta .venv e execute este arquivo novamente com Python 3.11+.
    goto :error
)

echo Conferindo dependencias...
".venv\Scripts\python.exe" -m pip install --disable-pip-version-check -q -r requirements.txt || goto :error

set "TESSERACT=C:\Program Files\Tesseract-OCR\tesseract.exe"
if exist "%TESSERACT%" goto :launch
where tesseract >nul 2>&1
if not errorlevel 1 goto :launch

echo.
echo [AVISO] Tesseract OCR nao encontrado.
where winget >nul 2>&1
if errorlevel 1 goto :tesseract_manual

echo Tentando instalar automaticamente via winget...
winget install UB-Mannheim.TesseractOCR --accept-package-agreements --accept-source-agreements
if exist "%TESSERACT%" goto :launch
where tesseract >nul 2>&1
if not errorlevel 1 goto :launch

:tesseract_manual
echo.
echo Nao foi possivel localizar/instalar o Tesseract automaticamente.
echo Instale manualmente com: winget install UB-Mannheim.TesseractOCR
echo Depois, se necessario, configure o caminho em Preferencias no aplicativo.
echo.

:launch
echo Abrindo aplicacao...
start "" ".venv\Scripts\pythonw.exe" main.py
if errorlevel 1 goto :error
endlocal
exit /b 0

:python_missing
echo [ERRO] Python nao encontrado.
echo Instale Python 3.11 ou superior e marque "Add Python to PATH".
goto :error

:python_old
echo [ERRO] O Python encontrado e anterior a 3.11.
echo Instale Python 3.11 ou superior e execute novamente.
goto :error

:error
echo.
echo [ERRO] A inicializacao nao foi concluida.
pause
endlocal
exit /b 1
