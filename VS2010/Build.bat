if exist .\obj\NUL del .\obj\*.* /s /q
if exist .\bin\NUL del .\bin\*.* /s /q

if not exist .\obj\NUL mkdir obj

cd ..

cd WixDatabaseSetupProjectTemplate
if exist .\obj\NUL del .\obj\*.* /s /q
if exist .\bin\NUL del .\bin\*.* /s /q
..\zip.exe -r ..\VS2010\obj\WixDatabaseSetupProjectTemplate *.*
cd ..

cd WixDatabaseUpdateProjectTemplate 
if exist .\obj\NUL del .\obj\*.* /s /q
if exist .\bin\NUL del .\bin\*.* /s /q
..\zip.exe -r ..\VS2010\obj\WixDatabaseUpdateProjectTemplate *.*
cd ..

cd WixSetupProjectTemplate 
if exist .\obj\NUL del .\obj\*.* /s /q
if exist .\bin\NUL del .\bin\*.* /s /q
..\zip.exe -r ..\VS2010\obj\WixSetupProjectTemplate *.*
cd ..

cd WixWebSetupProjectTemplate
if exist .\obj\NUL del .\obj\*.* /s /q
if exist .\bin\NUL del .\bin\*.* /s /q
..\zip.exe -r ..\VS2010\obj\WixWebSetupProjectTemplate *.*
cd ..

cd VS2010

if not exist .\bin\NUL mkdir bin
copy WixTemplates2010.vscontent .\obj

cd obj
..\..\zip.exe WixTemplates2010.vsi *.*
"C:\Program Files (x86)\Microsoft Visual Studio 11.0\Common7\IDE\MakeZipExe.exe" -zipfile:WixTemplates2010.vsi -output:..\bin\WixTemplates2010.vsi -overwrite
@rem "C:\Program Files\Microsoft SDKs\Windows\v6.0A\bin\signtool.exe" sign /f ..\abcsign.pfx /d "Wix templates" /du "http://www.abcsoftware.lv" ..\bin\WixTemplates2010.vsi
cd ..
