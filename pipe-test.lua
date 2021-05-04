local pipey = io.open("\\\\.\\pipe\\asoeuth", "r")

print('reader')

function on_timer()
    print('read')
    print(pipey:read("*l"))
    set_timer_timeout(100000)
end

set_timer_timeout(100000)