
;替换后的布局
/*
 `~  1 2 3 4 5 6 7 8 9 0 - = backsp
Tab   Q W F P G J L U Y ; [ ]  \
Back   A R S T D H N E I O " Enterr
LShift  Z X C V B K M , . / RShiftt
Ctrl Win Alt  Space Alt Menu Fn Ctrl
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

;这里是替换大写和退格
CapsLock::BackSpace
;大写切换不会经常用,平时用shift
LShift & CapsLock::CapsLock


;方向组合
LAlt & i::send {up}
LAlt & k::send {Down}
LAlt & j::send {Left}
LAlt & l::send {Right}

;<h-o> =>> Home End
LAlt & h::send {Home}
LAlt & `;::send {End}

/*
现在就是这样子了

     u
 h n e i o

     ↑
<< ← ↓ → >>

*/
