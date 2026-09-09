@echo off
setlocal
cd /d "%~dp0\.."

if not exist .venv\Scripts\python.exe (
  where python >nul 2>&1
  if errorlevel 1 goto :python_missing
  python -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)" >nul 2>&1
  if errorlevel 1 goto :python_old
  echo Criando ambiente virtual...
  python -m venv .venv || goto :error
)

.venv\Scripts\python.exe -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)" >nul 2>&1
if errorlevel 1 goto :venv_invalid

.venv\Scripts\python.exe -m pip install -r requirements-dev.txt || goto :error
.venv\Scripts\python.exe -m PyInstaller --noconfirm --windowed --name TimesheetBancoHoras main.py || goto :error

echo.
echo Build concluido. Verifique dist\TimesheetBancoHoras\TimesheetBancoHoras.exe
exit /b 0

:python_missing
echo [ERRO] Python nao encontrado. Instale Python 3.11 ou superior.
goto :error

:python_old
echo [ERRO] O Python encontrado e anterior a 3.11.
goto :error

:venv_invalid
echo [ERRO] A pasta .venv usa Python antigo ou esta corrompida.
echo Apague .venv e execute o build novamente.
goto :error

:error
echo.
echo [ERRO] O build nao foi concluido. Consulte as mensagens acima.
exit /b 1
