
cgrep: cgrep.cc
	g++ $< -o $@
	cp $@ ..
	md5sum $@ >../$@.md5


clean:
	for t in *.cc; do rm $(basename $t .cc); done
