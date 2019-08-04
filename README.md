# shftlock - ancient DOS TSR 

ShftLock was the first 80x86 assembly code I wrote. It had a simple purpose - turn a DOS keyboard layout into one that 
behaved like a typewriter. Many people won't remember what that means (and probably assume computer keyboards are much
the same as typewriters) but in fact there were enough differences that it created issues for professional typists who
were migrating from manual typewriters (and for that matter, dedicated word processing workstations, which mimicked
typewriter keyboards).

From what I can recall, the TSR takes up about 160 bytes of RAM when installed. When writing this, my first cut used about
500 bytes. I spoke to a mentor (who was and no doubt still is a genius at assembly code) and told him what the TSR did and
that I had got it down to 500 bytes. Without even looking at the code he said 'you should be able to do that in less than
200 bytes.' 
