package main

import (
  "fmt"
  "net/http"
  "github.com/julienschmidt/httprouter"
  log "github.com/sirupsen/logrus"
  "github.com/streadway/amqp"
  "os"
)

var HOST = os.Getenv("RABBIT_HOST")
var PORT = os.Getenv("RABBIT_PORT") 
var USERNAME = os.Getenv("RABBIT_USERNAME")
var PASSWORD = os.Getenv("RABBIT_PASSWORD")

func main() {

  router := httprouter.New()

  // curl -X POST http://localhost:4000/publish/world
  router.POST("/publish/:message", func(w http.ResponseWriter, r *http.Request, p httprouter.Params){
    submit(w,r,p)
  })

  fmt.Println("Listening on port 4000")
  
  log.Fatal(http.ListenAndServe(":4000", router))
}

func submit(writer http.ResponseWriter, request *http.Request, p httprouter.Params) {
  message := p.ByName("message")
  
  fmt.Println("message: " + message)

  conn, err := amqp.Dial("amqp://" + USERNAME + ":" + PASSWORD + "@" + HOST + ":" + PORT + "/")

  if err != nil {
    log.Fatalf("%s: %s", "Failed to connect to RabbitMQ", err)
  }

  defer conn.Close()

  ch, err := conn.Channel()

  if err != nil {
    log.Fatalf("%s: %s", "Failed to open a channel", err)
  }

  defer ch.Close()

  q, err := ch.QueueDeclare(
    "publisher",  // name
    true,         // durable
    false,        // delete when unused
    false,        // exclusive
    false,        // no-wait
    nil,          // arguments
  )

  if err != nil {
    log.Fatalf("%s: %s", "Failed to declare a queue", err)
  }

  err = ch.Publish(
    "",     // exchange
    q.Name, // routing key
    false,  // mandatory
    false,  // immediate
    amqp.Publishing {
      ContentType: "text/plain",
      Body:        []byte(message),
  })

  if err != nil {
    log.Fatalf("%s: %s", "Failed to publish a message", err)
  }
}