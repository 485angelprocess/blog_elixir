%{
	title: "Simple TCP Listener in Rust",
	author: "Annabelle Adelaide",
	tags: ~w(rust,tcp),
	description: ""
}
---
# Simple TCP Listener in Rust

For a project I'm working on I needed to implement some level of inter process communication. I have a server which should be able receive functions from multiple clients (remote or local). TCP feels like a logical conclusion for this application.

The basic TCP server route looks like this:

```rust
use std::thread;
use std::io{TcpListener, TcpStream, Shutdown};

fn handle_client(mut stream: TcpStream){
    let mut data = [0 as u8; 256]; // Data buffer
    while match stream.read(&mut data){
        Ok(size) => {
            if size > 0{
                // Read in data/response
                //...
            }
            true // Continue loop
        },
        Err(e) => {
            println!("Error: {:?}", e);
            stream.shutdown(Shutdown::Both).unwrap();
            false; // Exit loop
        }
    }
}

fn connect(port: usize){
    let listener = TcpListener::bind(format!("127.0.0.1:{port}")).unwrap();
    
    for stream in listener.incoming(){
        Ok(stream) => {
            // Got new connection
            std::thread::spawn(||{handle_client(stream)});
        }
        Err(e) => {
            // Error on connection
            println!("Connection error: {}", e);
        }
    }
}

fn main(){
    connect(9000); // Start server on port 9000
}
```

This can handle multiple connections by placing each connection in a thread. Data is received in buffers. For now I'm controlling the applications on both sides, so I'm using a custom protocol. At some point I'll add some ability to interoperate with a browser by handling http. 

Since I want a functional interface, I wanted to define what type of requests the server would get. Most requests will be write-only, with some read only requests.

```rust
enum Value{
    Int(isize),
    Float(f64),
    Str(String)    
}

struct Request{
    label: String,
    thread_index: usize,
    args: Vec<Value>
}
```

Every request is a string label which points to the function I want to run. It also has a thread index so that read requests can go back to the correct client. Functions expect some number of types arguments, which I limited to simplify function writing.

Now I just use some method to go from bytes to a request and save the thread index. For my custom protocol I made this a simple parser. It's unimportant for now. To share the results back to the core server application, I use an `Arc<Mutex<Vec<Request>>>` to share a buffer of requests.

Server requests can add to the buffer, and at each run of the server's main loop it'll go through all pending requests. For my application, the `connect` function was also moved to another thread, as I want to have a gui occupying the main thread with minimal other things going on.

Next I'm writing an API which I can use to read and write from my server. I may use `warp` or check out more of [rust-api.dev](https://rust-api.dev/docs/part-1/introduction/), or just make a simple one for now.


