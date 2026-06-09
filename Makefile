.PHONY: demo test clean

demo:    ## run the example pipeline end to end
	./bin/conductor init demo --goal "summarize a document"
	./bin/conductor run all demo
	./bin/conductor status demo

test:    ## smoke + schema tests
	bash tests/test_pipeline.sh

clean:
	rm -rf runs runs_test
