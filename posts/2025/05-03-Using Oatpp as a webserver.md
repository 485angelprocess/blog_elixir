%{
	title: "Using Oatpp as a webserver",
	author: "Annabelle Adelaide",
	tags: ~w(c++,oatpp),
	description: ""
}
---
# Using Oatpp as a webserver

[Oat++](https://oatpp.io/) is a open source C++ web framework I wanted to check out. It is a small framework aimed for embedded devices. I want to start by just getting a basic project up and seeing some of the features.

## Getting things running

I followed the step-by-step guide, starting with just a minimal port connection.

In `Main.cpp`

```cpp
include "oatpp/web/server/HttpConnectionHandler.hpp"

#include "oatpp/network/Server.hpp"
#include "oatpp/network/tcp/server/ConnectionProvider.hpp"

/* Oat pp basic server */
/* https://oatpp.io/docs/start/step-by-step/#api-low-level-components-overview */

void run(){
  /**
    Runs server
  **/
  auto router = oatpp::web::server::HttpRouter::createShared();

  auto connectionHandler = oatpp::web::server::HttpConnectionHandler::createShared(router);

  auto connectionProvider = oatpp::network::tcp::server::ConnectionProvider::createShared({
                                          "localhost", 8010, oatpp::network::Address::IP_4
                                                               });

  oatpp::network::Server server(connectionProvider, connectionHandler);

  OATPP_LOGi("noise_app", "Server running on port {}", connectionProvider->getProperty("port").toString());

  server.run();
}

int main(){

  oatpp::Environment::init();

  run();

  oatpp::Environment::destroy();

  return 0;
}


```

I had to modify this slightly from the web pages tutorial since Oatpp has updated a bit. This enters the oatpp environment, creates an http router on a port and launches the server.

The `CMakeLists.txt` file:

```cpp
cmake_minimum_required(VERSION 3.20)

set(project_name noise-game)

project(${project_name})

set(CMAKE_CXX_STANDARD 17)

# Libraries
add_library(${project_name}-lib
    src/AppComponent.hpp
)

find_package(oatpp 1.4.0 REQUIRED)

target_link_libraries(${project_name}-lib
    PUBLIC oatpp::oatpp
    PUBLIC oatpp::oatpp-test
)

target_include_directories(${project_name}-lib PUBLIC src)

## Add exectuables
message(STATIC "Building ${project_name}-exe")
add_executable(${project_name}-exe
    src/Main.cpp)
target_link_libraries(${project_name}-exe ${project_name}-lib)
add_dependencies(${project_name}-exe ${project_name}-lib)

set_target_properties(${project_name}-lib ${project_name}-exe PROPERTIES
        CXX_STANDARD 17
        CXX_EXTENSIONS OFF
        CXX_STANDARD_REQUIRED ON
)



```

## Handler

This won't do anything yet. First I added a handler:

```cpp
class Handler: public oatpp::web::server::HttpRequestHandler{
  public:
    /**
     * Handle incoming request and return outgoing response.
     */
     std::shared_ptr<OutgoingResponse> handle(const std::shared_ptr<IncomingRequest>& request) override{
       return ResponseFactory::createResponse(Status::CODE_200, "Hello World!");
     }
};

```

Then linked this to the router:

```cpp
... declare router

// Route GET
router->route("GET", "/hello", std::make_shared<Handler>());


... Create connection handler
```

Using curl locally replies with hello world:

```bash
$ curl http://localhost:8010/hello
Hello World
```

Now I had an issue getting curl to run with it listed as localhost from a different computer. I believe this is an issue with my local network's DNS setup but setting oat to run from the local ip allowed it to run across the network.

## Retrieving structured data

While it's nice that I can get basic text, I would like JSON data. Oat uses data transfer objects, which is just packaging data in a json. This is just server state data that can be easily read/written to by a client application.

To make adding more components easier, I first created `AppComponent.cpp` to hold application components, which makes it easier to create and manage them. This is at the suggestion of the Oatpp documentation which provides a template project structure.

`AppComponent.cpp`:

```cpp
#pragma once

#include "oatpp/json/ObjectMapper.hpp"

#include "oatpp/web/server/HttpConnectionHandler.hpp"
#include "oatpp/network/tcp/server/ConnectionProvider.hpp"

#include "oatpp/macro/component.hpp"

/**
 * Class which creates and hold Application components and registers
 * Order of component initialization is from top to bottom
 */
class AppComponent{
public:
    /**
     * Create connectionprovider component which listens on the port
     */
    OATPP_CREATE_COMPONENT(std::shared_ptr<oatpp::network::ServerConnectionProvider>, serverConnectionProvider)([>
      return oatpp::network::tcp::server::ConnectionProvider::createShared({"localhost", 8010, oatpp::networ>
    }());
 
   /**
   *  Create Router component
   */
  OATPP_CREATE_COMPONENT(std::shared_ptr<oatpp::web::server::HttpRouter>, httpRouter)([] {
    return oatpp::web::server::HttpRouter::createShared();
  }());

  /**
   *  Create ConnectionHandler component which uses Router component to route requests
   */
  OATPP_CREATE_COMPONENT(std::shared_ptr<oatpp::network::ConnectionHandler>, serverConnectionHandler)([] {
    OATPP_COMPONENT(std::shared_ptr<oatpp::web::server::HttpRouter>, router); // get Router component
    return oatpp::web::server::HttpConnectionHandler::createShared(router);
  }());

  /**
   *  Create ObjectMapper component to serialize/deserialize DTOs in Contoller's API
   */
  OATPP_CREATE_COMPONENT(std::shared_ptr<oatpp::data::mapping::ObjectMapper>, apiObjectMapper)([] {
    auto json = std::make_shared<oatpp::json::ObjectMapper>();
    return json;
  }());

};

```

This has some minor changes from the walkthrough to make it match the newest updates. 

Next I created a DTO to hold some data. Oat makes this a kind of macro generation. To me, this seems a bit kludgy for C++, but it does do the job. Trying to smush JSON into C++ is going to be a bit wonky no matter what, so maybe this is the most elegant with low overhead.

```c++
#include OATPP_CODEGEN_BEGIN(DTO)

/**
  * Message Data-Transfer-Object
  */
class MessageDto: public oatpp::DTO{
  DTO_INIT(MessageDto, DTO /* Extends*/)

  DTO_FIELD(Int32, statusCode);
  DTO_FIELD(String, message);
};

#include OATPP_CODEGEN_END(DTO)
```

I can now go back in the editor and have it send the DTO instead of just a bare string.

The `handle` method of `Handler` is now:

```c++
std::shared_ptr<OutgoingResponse> handle(const std::shared_ptr<IncomingRequest>& request) override{
    auto message = MessageDto::createShared();
    message->statusCode = 1024;
    message->message = "Hello DTO!";
    return ResponseFactory::createResponse(Status::CODE_200, message, m_objectMapper);
}
```

This now gives a json response:

```bash
$ curl http://localhost:8010/hello
{"statusCode":1024,"message":"Hello DTO!"}
```

I'm going to explore a bit more into Oatpp, but this was a pretty decent look at getting up and running. It seems like a good framework for embedded devices, not super intense to set up, and claims to be very performant. It's also nicely self-contained so doesn't create a headache of dependencies. The testing framework is something I want to look at some more of as well.
