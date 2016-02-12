[Mod] Tool for quickly placing lines consisting of nodes [linemaker]

I don't know how do describe this tool correctly.

Just hold right click and release when it's where it should be.  
The stack right to the tool gets placed from the startpos to the wantedpos.

click RMB on a node, hold aux1 to invert pt  
hold RMB, hold aux1 for a 2d line, hold right and left for a straight line  
left click a node to change range, hold shift to change pt, additionally hold aux1 to invert pt  
release RMB to set nodes, hold up and down to abort queue if placing didn't succeed

The tool can not only be used to place nodes in a line,  
it also supports the replacer or any tool in the next slot with an on_place.  
I'm wondering, what happens if you have a linemaker tool in the next slot and another one in the third one?

Crafting:  
![I'm a sad!](https://d2.maxfile.ro/yqplarignf.png)

**Depends:** see [depends.txt](https://raw.githubusercontent.com/HybridDog/linemaker/master/depends.txt)  
**License:** see [LICENSE.txt](https://raw.githubusercontent.com/HybridDog/linemaker/master/LICENSE.txt)  
**Download:** [zip](https://github.com/HybridDog/linemaker/archive/master.zip), [tar.gz](https://github.com/HybridDog/linemaker/tarball/master)  

![I'm a screenshot!](https://d2.maxfile.ro/ifmyazpowl.png)

If you got ideas or found bugs, please tell them to me.

[How to install a mod?](http://wiki.minetest.net/Installing_Mods)


TODO:  
— find out why the fist objects of the line don't always exist  
— test it in survival mode
