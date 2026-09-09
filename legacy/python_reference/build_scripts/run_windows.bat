@echo off
setlocal
cd /d "%~dp0\.."

where python >nul 2>&1
if errorlevel 1 goto :python_missing
python -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)" >nul 2>&1
if errorlevel 1 goto :python_old

if not exist ".venv\Scripts\python.exe" (
  echo Criando ambiente virtual...
  python -m venv .venv || goto :error
)

".venv\Scripts\python.exe" -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)" >nul 2>&1
if errorlevel 1 goto :venv_invalid

".venv\Scripts\python.exe" -m pip install --disable-pip-version-check -r requirements.txt || goto :error
".venv\Scripts\python.exe" main.py
set "APP_EXIT=%ERRORLEVEL%"
if not "%APP_EXIT%"=="0" goto :app_error
exit /b 0

:python_missing
echo [ERRO] Python nao encontrado. Instale Python 3.11 ou superior.
goto :error

:python_old
echo [ERRO] O Python encontrado e anterior a 3.11.
goto :error

:venv_invalid
echo [ERRO] A pasta .venv usa Python antigo ou esta corrompida.
echo Apague .venv e execute novamente.
goto :error

:app_error
echo [ERRO] A aplicacao encerrou com codigo %APP_EXIT%.
exit /b %APP_EXIT%

:error
exit /b 1
