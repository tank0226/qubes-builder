CMD /C "CD /D %CD%\winpvdrivers && makedist" || GOTO END
CMD /C "CD /D %CD%\core\win && makedist" || GOTO END

CMD /C "CD /D %CD% && wix" || GOTO END

:END