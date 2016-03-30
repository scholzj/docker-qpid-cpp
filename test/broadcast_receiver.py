#! /usr/bin/python

import sys
import time
from qpid.messaging import *
from qpid.log import enable, DEBUG

#enable("qpid", DEBUG)

response_address_stream = "broadcast.ABCFR_ABCFRALMMACC1.TradeConfirmation; { node: { type: queue } , create: never , mode: consume , assert: never }"

message_no = 0
block_size = 100
time_tick = 1000
timeout = 1
block_message_size = 0
total_message_size = 0

try:
  connection = Connection(host="localhost", port="5671", username="user1", sasl_mechanisms="EXTERNAL", transport="ssl", ssl_keyfile="./user1.pem", ssl_certfile="./user1.crt", ssl_trustfile="./localhost.crt", heartbeat=60)
  connection.open()
  session = connection.session()
  receiver_stream = session.receiver(response_address_stream)
  receiver_stream.capacity = 1000
  total_start_time = time.time()
  block_start_time = total_start_time

  while True:
    try:
      message = receiver_stream.fetch(timeout=timeout)
    except Empty:
      session.acknowledge(sync=True)
      block_end_time = time.time()
      total_end_time = block_end_time
      print "-I- ", message_no, "messages received;", ((message_no % time_tick)/(block_end_time-block_start_time-timeout)), "msg/s; ", (block_message_size/(block_end_time-block_start_time-timeout)/1024), " kB/s"
      break;

    message_no += 1
    message_size = len(message.content)
    block_message_size = block_message_size + message_size
    total_message_size = total_message_size + message_size

    if message_no % block_size == 0:
      session.acknowledge(sync=True)

    if message_no % time_tick == 0:
      block_end_time = time.time()
      print "-I- ", message_no, "messages received;", (time_tick/(block_end_time-block_start_time)), "msg/s; ", (block_message_size/(block_end_time-block_start_time)/1024), " kB/s"
      block_start_time = time.time()
      block_message_size = 0

  print "-I- Total ", message_no, " messages received;", (message_no/(total_end_time-total_start_time-timeout)), "msg/s; ", (total_message_size/(total_end_time-total_start_time-timeout)/1024), " kB/s"

  receiver_stream.close()
  session.close()
  connection.close()
except MessagingError,m:
  print m
