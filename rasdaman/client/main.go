package main

func main() {
	// This is the main entry point for the rasdaman client.
	// It will initialize the load generator and start the workers.
	// The actual implementation of the load generator and workers
	// is in the loadgen.go file.
	println("Rasdaman client is starting...")
	loadgen() // Call the loadgen function to start the load generation process
}
