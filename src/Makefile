
CXX=g++

cgrep: cgrep.cc
	$(CXX) $< -o $@ -std=c++17
	cp $@ ..
	md5sum $@ >../$@.md5


clean:
	for t in *.cc; do rm $(basename $t .cc); done
