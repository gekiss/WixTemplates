if exist .\obj\NUL del .\obj\*.* /s /q
if exist .\bin\NUL del .\bin\*.* /s /q

if not exist .\obj\NUL mkdir obj

cd ..

cd WixDatabaseSetupProjectTemplate
if exist .\obj\NUL del .\obj\*.* /s /q
if exist .\bin\NUL del .\bin\*.* /s /q
..\zip.exe -r ..\VS2008\obj\WixDatabaseSetupProjectTemplate *.*
cd ..

cd WixDatabaseUpdateProjectTemplate 
if exist .\obj\NUL del .\obj\*.* /s /q
if exist .\bin\NUL del .\bin\*.* /s /q
..\zip.exe -r ..\VS2008\obj\WixDatabaseUpdateProjectTemplate *.*
cd ..

cd WixSetupProjectTemplate 
if exist .\obj\NUL del .\obj\*.* /s /q
if exist .\bin\NUL del .\bin\*.* /s /q
..\zip.exe -r ..\VS2008\obj\WixSetupProjectTemplate *.*
cd ..

cd VS2008

if not exist .\bin\NUL mkdir bin
copy WixTemplates2008.vscontent .\obj

cd obj
..\..\zip.exe WixTemplates2008.vsi *.*
"C:\Program Files (x86)\Microsoft Visual Studio 10.0\Common7\IDE\MakeZipExe.exe" -zipfile:WixTemplates2008.vsi -output:..\bin\WixTemplates2008.vsi -overwrite
@rem "C:\Program Files\Microsoft SDKs\Windows\v6.0A\bin\signtool.exe" sign /f ..\abcsign.pfx /d "Wix templates" /du "http://www.abcsoftware.lv" ..\bin\WixTemplates2008.vsi
cd ..
