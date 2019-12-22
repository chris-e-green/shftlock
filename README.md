# shftlock - ancient DOS TSR 

ShftLock was the first (professional) 80x86 assembly code I wrote. It had a simple purpose - turn a DOS keyboard layout into one that 
behaved like a typewriter. Many people won't remember what that means (and probably assume computer keyboards are much
the same as typewriters) but in fact there were enough differences that it created issues for professional typists who
were migrating from manual typewriters (and for that matter, dedicated word processing workstations, which mimicked
typewriter keyboards).

From what I can recall, the TSR takes up about 160 bytes of RAM when installed. When writing this, my first cut used about
500 bytes. I spoke to a mentor (who was and no doubt still is a genius at assembly code) and told him what the TSR did and
that I had got it down to 500 bytes. Without even looking at the code he said 'you should be able to do that in less than
200 bytes.'  Sure enough, looking at it again, and rethinking some of my initial naive assembly, he was right. 

It was an interesting lesson in efficiency vs readability - I was doing things like `mov ax, 0` instead of `xor ax,ax`. The end result is the same but the `MOV` command more memory and runs slower than the `XOR`. These days, nobody really cares about how much memory something uses (until it's in the gigabytes!) but when you had - at best - 640K to work with, and your code might be running the whole time the computer was on, it did matter.
