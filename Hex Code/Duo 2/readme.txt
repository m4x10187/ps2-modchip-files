so here's my contribution to the ps2 scene, a basic one. a duo2 clone for use with magic ice. this was done as an intro project to learn cadding which a mate helped me with (he did bulk of work of cad and sent it to me but had many errors which corrected. still appreciate him doing that as was lot easier to get head round cad software with something done to play with)
the letter refs have been changed on the cad to match standard layout (normally magic ice flashed duo2 have 3x points swapped round).

cad is easyeda file, gerber of that file included.

codes contain the 2x final releases of ice being v1-12. there is also duo final.rar which has duo2 and duo2se code in them and one unknown that have dumped from duo2 here.
I have tested on v5/6 all (besides duo2se code as not for this design) and all appear to operate. also tested on a v12, only Duo2IceFinal.hex works on it though rather buggy, for resets. Been so long since used ice code on slims can't remember if just how the final was or not.
the unknown works but not as well and fails to boot ps1 at all even forcing mode, maybe a beta???
none of these code have dvd9 support, hence look for program ToxicDualLayerPatcher-v1.0.zip which can be used to patch dvd9 backups to work. (the mods that support dvd9 just do this on the fly)


you will need a sx programmer such as sxkey (which long dc and out of stock). Or can diy your own fluffy2, link http://www.ic-prog.com/fluffy2.html

bom is as followed(use included duo2 pic to work out placement, as didn't set c r labels. ic line up to as silkskin marked)
work out yourself where to source these from. pcb cad has been assembled and tested by myself, working 100% as should.
2x 33k 0805
1x 100k 0805
1x 100nf 0805
1x 74hc107d
1x sx48
1x 50mhz ceramic resonator

diagrams are for subzero but match 100% as needed, check ICE_FINAL.txt in diagrams for needed dvd/cd points. F=TR and is always needed for autoboot mode.


Hopefuly some of the devs of this great mod code see this and release the later closed versions, hopefully haven't pissed them off including the other codes

pack alters just to rename the 2x duo2 dumps I did from ones still on hand and once noticed code matched 100% to spanish forum pack included it as downloaded, left the unknown in and named to match.

and yes know the cads ugly, was first attempt.

found where the v14 was posted on archive dumps but no files, if anyone has these please share.

https://web.archive.org/web/20080217013647/http://www.spainconsoles.com/foros/index.php?act=attach&code=showtopic&tid=88

edit noticed listed wrong smd size, is 0805. cad i did 0603 by mistake. 0805 fit fine, update the gerber if you wish.