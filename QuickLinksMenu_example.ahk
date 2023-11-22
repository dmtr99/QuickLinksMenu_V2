#Requires AutoHotkey v2.0
#Include QuickLinksMenu.ahk

oMenu := QuickLinksMenu()
TrayTip("Press the [Capslock] key to show the menu")
return

CapsLock::{
oMenu.Show()
return
}