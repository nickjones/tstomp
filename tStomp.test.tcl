# Stomp.test

package require tcltest

namespace import -force ::tcltest::*

# namespace import overrides debug command
# so we have to reoverride the command
proc debug {args} {
	puts "[lindex $args 0]"
}

# Software under test
package require tStomp

# Setting Serveraddress and port
set ::serverAddress desw138x
set ::serverPort 61612
set ::runs 0

proc getNewQueue {} {
	set queue "/queue/test."
	append queue [string trim [clock clicks] -]
	return $queue
}

proc stompcallback {messageNvList} {

	puts "------------------------------"
	foreach {name value} [join $messageNvList] {
		set ::$name $value
		puts "#-#-# $name '$value'"

	}
	puts "------------------------------"

}



test Stomp_connect {} -body {
	puts "## Stomp_connect"
	# Connect
	catch {delete object ::s}
	tStomp ::s $::serverAddress $::serverPort
	::s connect {set ::result CONNECTED}
	after 5000 [list set ::result "NOT CONNECTED"]
	vwait ::result
	if {$::result == "NOT CONNECTED"} {
		error "In testcase 'Stomp_connect' Connection failed"
		puts "### NOT CONNECTED"
	}

	if ![::s getIsConnected] {
		error "In testcase 'Stomp_connect' Not Connected"
	}
	
	# two connects to same socket not possible
	if {[catch {::s connect {set ::result CONNECTED}}] == 0} {
		error "In testcase 'Stomp_connect' Connect twice possible"
	}

	# disconnect
	if {[::s disconnect] != 1} {
		error "In testcase 'Stomp_connect Disconnect failed'"
	}

	# second connect with new script
	::s connect {set ::result2 CONNECTED}
	after 5000 [list set ::result2 "NOT CONNECTED"]
	vwait ::result2
	if {$::result2 == "NOT CONNECTED"} {
		error "In testcase 'Stomp_connect' Connection two failed"
		puts "### NOT CONNECTED"
	}

	return 1	
} -result "1"


test Stomp_disconnect {} -body {
	puts "## Stomp_disconnect"
	catch {delete object ::s}
	tStomp ::s $::serverAddress $::serverPort

	# disconnect
	if {[catch {::s disconnect}] == 0} {
		error "In testcase 'Stomp_disconnect' Disconnect faild"
	}

	if [::s getIsConnected] {
		error "In testcase 'Stomp_disconnect' Still connected. Seems like disconnect doesn't work exactly"
	}

	return 1
} -result "1"


test Stomp_Send {} -body {
	puts "## Stomp_Send"
	set queue [getNewQueue]
	# Connect
	catch {delete object ::s}
	tStomp ::s $::serverAddress $::serverPort
	::s connect {set ::result CONNECTED}
	after 5000 [list set ::result "NOT CONNECTED"]
	vwait ::result

	if {[::s send $queue "Stomp_Send"] != 1} {
		error "In testcase 'Stomp_Send' Send to queue faild"
	} else {
		set res 1
	}

	# disconnect
	if {[::s disconnect] != 1} {
		error "In testcase 'Stomp_send' Disconnect faild"
	}
	
	return $res
} -result "1"


test Stomp_subscribe {} -body {
	puts "## Stomp_subscribe"
	set queue_subscribe [getNewQueue]
	# Connect
	catch {delete object ::s}
	tStomp ::s $::serverAddress $::serverPort
	::s connect {set ::result CONNECTED}
	after 5000 [list set ::result "NOT CONNECTED"]
	vwait ::result

	# subscribe
	if {[::s subscribe $queue_subscribe {stompcallback $messageNvList}] != 1} {
		error "In testcase 'Stomp_subscribe' Subscrib to queue faild"
	}

	after 1000 [list ::s send $queue_subscribe "Stomp_subscribe"]
	set afterId [after 5000 [list set ::messagebody ERROR]]
	vwait ::messagebody
	catch {after cancel $afterID}

	if {[string match "Stomp_subscribe*" $::messagebody] != 1} {
		error "In testcase 'Stomp_subscribe' getting a message failed"
	}

	# unsubscribe
	if {[::s unsubscribe $queue_subscribe] != 1} {
		error "In testcase 'Stomp_subscribe' Unsubscribe failed"
	}

	# disconnect
	if {[::s disconnect] != 1} {
		error "In testcase 'Stomp_subscribe' Disconnect faild"
	}
	
	# subscribe without connection
	if {[catch {::s subscribe $queue_subscribe {stompcallback $messageNvList}}] == 1} {
		error "In testcase 'Stomp_subscribe' subscribe without connection not possible"
	}

	# Connect
	::s connect {set ::result CONNECTED}
	after 5000 [list set ::result "NOT CONNECTED"]
	vwait ::result

	# send
	unset ::messagebody
	::s send $queue_subscribe "Stomp_2subscribe"
	after 5000 [list set ::messagebody ERROR]
	vwait ::messagebody

	if {[string match "Stomp_2subscribe*" $::messagebody] != 1} {
		error "In testcase 'Stomp_subscribe' getting a message failed (connect after subscribe)"
	}

	return 1

} -result "1"


test Stomp_unsubscribe {} -body {
	puts "## Stomp_unsubscribe"
	set queue_unsubscribe [getNewQueue]
	catch {delete object ::s}
	tStomp ::s $::serverAddress $::serverPort

	# unsubscribed
	if {[catch {::s unsubscribe $queue_unsubscribe}] == 0} {
		error "In testcase 'Stomp_unsubscribe' (Not connected and not subscribed) Unsubscribe failed"
	}

	# Connect
	::s connect {set ::result CONNECTED}
	after 5000 [list set ::result "NOT CONNECTED"]
	vwait ::result
	
	# unsubscribe
	if {[catch {::s unsubscribe $queue_unsubscribe}] == 0} {
		error "In testcase 'Stomp_unsubscribe' (Not subscribed) Unsubscribe failed"
	}
	
	# subscribe
	::s subscribe $queue_unsubscribe {stompcallback $messageNvList}

	# unsubscribe
	if {[::s unsubscribe $queue_unsubscribe] != 1} {
		error "In testcase 'Stomp_unsubscribe' (Connected and subscribed) Unsubscribe failed"
	}

	# unsubscribe
	if {[catch {::s unsubscribe $queue_unsubscribe}] == 0} {
		error "In testcase 'Stomp_unsubscribe' (Not subscribed again) Unsubscribe failed"
	}

	::s send $queue_unsubscribe "Stomp_unsubscribe"
	after 2000 [list set ::messagebody unsubscribed]
	vwait ::messagebody


	if {[string match "Stomp_unsubscribe*" $::messagebody]} {
		error "In testcase 'Stomp_unsubscribe' Messagebody contains result of sent message"
	}

	return 1

} -result "1"


test Stomp_handleLine {} -body {
	puts "## Stomp_handleLine"
	set queue_handleLine [getNewQueue]
	catch {delete object ::s}
	tStomp ::s $::serverAddress $::serverPort

	# Connect
	::s connect {set ::result CONNECTED}
	after 5000 [list set ::result "NOT CONNECTED"]
	vwait ::result
	
	# subscribe
	::s subscribe $queue_handleLine {stompcallback $messageNvList}

# list of line (from socket) and expected result
set message [list \
[list [list CONNECTED]								[list CONNECTED] [list ]] \
[list [list heart-beat:0,0]							[list CONNECTED] [list heart-beat 0,0]] \
[list [list session:ID:desw138x-38000-1339169069006-7494:231]			[list CONNECTED] [list session "ID:desw138x-38000-1339169069006-7494:231"]] \
[list [list server:ActiveMQ/5.6.0]						[list CONNECTED] [list server ActiveMQ/5.6.0]] \
[list [list version:1.1]							[list CONNECTED] [list version 1.1]] \
[list [list ]									[list CONNECTED] [list ]] \
[list [list  ]									[list CONNECTED] [list ]] \
[list [list MESSAGE]								[list MESSAGE] [list ]] \
[list [list message-id:ID\cdesw138x-38000-1339169069006-7494\c231\c-1\c1\c1]	[list MESSAGE] [list message-id "ID\cdesw138x-38000-1339169069006-7494\c231\c-1\c1\c1"]] \
[list [list destination:${queue_handleLine}]						[list MESSAGE] [list destination ${queue_handleLine}]] \
[list [list timestamp:1339425951090]						[list MESSAGE] [list timestamp 1339425951090]] \
[list [list expires:0]								[list MESSAGE] [list expires 0]] \
[list [list subscription:5C6E81DE507A8595EAE75291C6B187FD]			[list MESSAGE] [list subscription 5C6E81DE507A8595EAE75291C6B187FD]] \
[list [list persistent:true]							[list MESSAGE] [list persistent true]] \
[list [list priority:4]								[list MESSAGE] [list priority 4]] \
[list [list ]									[list MESSAGE] [list ]] \
[list [list 234234 queue chriss.test3]						[list MESSAGE] [list messagebody {234234 queue chriss.test3}]] \
[list [list  ]									[list MESSAGE] [list ]] \
[list [list MESSAGE]								[list MESSAGE] [list ]] \
[list [list message-id:ID\cdesw138x-38000-1339169069006-7494\c231\c-1\c1\c2]	[list MESSAGE] [list message-id "ID\cdesw138x-38000-1339169069006-7494\c231\c-1\c1\c2"]] \
[list [list destination:${queue_handleLine}]						[list MESSAGE] [list destination ${queue_handleLine}]] \
[list [list timestamp:1339426287323]						[list MESSAGE] [list timestamp 1339426287323]] \
[list [list expires:0]								[list MESSAGE] [list expires 0]] \
[list [list subscription:5C6E81DE507A8595EAE75291C6B187FD]			[list MESSAGE] [list subscription 5C6E81DE507A8595EAE75291C6B187FD]] \
[list [list persistent:true]							[list MESSAGE] [list persistent true]] \
[list [list priority:4]								[list MESSAGE] [list priority 4]] \
[list [list ]									[list MESSAGE] [list ]] \
[list [list 234234 queue chriss.test3]						[list MESSAGE] [list messagebody {234234 queue chriss.test3}]] \
[list [list  ]									[list MESSAGE] [list ]] \
]

	foreach test $message {

		set res [::s testHandleLine [lindex $test 0]]
		# puts "$res"

		array set resArr [lindex $res 0]

		if {[lindex $test 1] != [lindex $res 1]} {
			error "readCommand is wrong ([lindex $test 1] == [lindex $res 1])"
		}

		if {[string length [set testVar [lindex $test 2]]]} {
			set varName [lindex $testVar 0]
			set varVal [lindex $testVar 1]
			if {[info exists resArr($varName)]} {
				if {$resArr($varName) != $varVal} {
					error "$resArr($varName) != $varVal"
				}
			} else {
				error "resArr($varName) not existing"
			}
		}
	}

	return 1

} -result "1"


cleanupTests
return

