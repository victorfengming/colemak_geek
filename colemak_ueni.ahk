
/*
* author:@victorfegming
* address:gitee.com/victorfengming
* 项目下载:https://gitee.com/victorfengming/colmak_autohotkey
* 博客地址:https://victorfengming.gitee.io/
*/


;先看效果:替换后的布局
/*
 `~  1 2 3 4 5 6 7 8 9 0 - = backsp
Tab   Q W F P G J L U Y ; [ ]  \
Back   A R S T D H N E I O " Enterr
LShift  Z X C V B K M , . / RShiftt
Ctrl Win Alt  Space Alt Menu Fn Ctrl
*/

/*

   l u y
 h n e i o '

   up↑down
<< ← ↓ → >> del

*/


;colemak的对应QWERTY键位
e::f
r::p
t::g
y::j
u::l
i::u
o::y
p::;
s::r
d::s
f::t
g::d
j::n
k::e
l::i
`;::o
n::k
; 这里的替换不会影响组合的修饰符
; 比如现在按Ctrl+F就是Ctrl+F,不会是原来的Ctrl+E

;这里是替换大写和退格
CapsLock::BackSpace
;大写切换不会经常用,平时用shift
LShift & CapsLock::CapsLock
;强烈建议这里换成删除,因为删除的按键距离主键盘过远,影响打字效率

;Alt 的 方向组合
<!i::send {up}
<!k::send {Down}
<!j::send {Left}
<!l::send {Right}
<!'::send {Del}
;<h-o> =>> Home End
<!h::send {Home}
<!`;::send {End}


;Alt shift组合方向键
<+<!i::send {Shift down}{up}
<+<!k::send {Shift down}{Down}
<+<!j::send {Shift down}{Left}
<+<!l::send {Shift down}{Right}
<+<!h::send {Shift down}{Home}
<+<!`;::send {Shift down}{End}
<+<!'::send {Shift down}{Del}

;Alt ctrl组合方向键
<^<!i::send {Ctrl down}{up}
<^<!k::send {Ctrl down}{Down}
<^<!j::send {Ctrl down}{Left}
<^<!l::send {Ctrl down}{Right}
<^<!h::send {Ctrl down}{Home}
<^<!`;::send {Ctrl down}{End}

;Alt Ctrl Shift 组合方向键
<^<+<!i::send {Ctrl down}{Shift down}{up}
<^<+<!k::send {Ctrl down}{Shift down}{Down}
<^<+<!j::send {Ctrl down}{Shift down}{Left}
<^<+<!l::send {Ctrl down}{Shift down}{Right}
<^<+<!h::send {Ctrl down}{Shift down}{Home}
<^<+<!`;::send {Ctrl down}{Shift down}{End}

;Alt + ly page↑page↓
<!u::send {PgUp}
<!o::send {PgDn}

;禁止方向键，提醒使用主键盘
up::return
Down::return
Left::return
Right::return


/*
相关知识点:
- 原文地址:http://ahkcn.sourceforge.net/docs/AutoHotkey.htm
- 映射表地址:http://ahkcn.sourceforge.net/docs/KeyList.htm
- :: 表示映射
- send 发送组合键
- `符号用来转义;分号
- 修饰符 Ctrl Alt Shift 对应 ^+!
- down表示按下的状态
- &表示组合键
- <表示只有左边的修饰符生效
- return 啥也不干
*/