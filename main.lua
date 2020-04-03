push = require 'push'

-- the "Class" library we're using will allow us to represent anything in
-- our game as code, rather than keeping track of many disparate variables and
-- methods
--
-- https://github.com/vrld/hump/blob/master/class.lua
Class = require 'class'

-- our Paddle class, which stores position and dimensions for each Paddle
-- and the logic for rendering them
require 'Paddle'

-- our Ball class, which isn't much different than a Paddle structure-wise
-- but which will mechanically function very differently
require 'Ball'

WINDOW_WIDTH = 1280
WINDOW_HEIGHT = 720

VIRTUAL_WIDTH = 432
VIRTUAL_HEIGHT = 243

-- speed at which we will move our paddle; multiplied by dt in update
PADDLE_SPEED = 200

--[[
    Runs when the game first starts up, only once; used to initialize the game.
]]

--resize the window
function love.resize(w, h)
    push:resize(w, h)
end

function love.load()
    -- set love's default filter to "nearest-neighbor", which essentially
    -- means there will be no filtering of pixels (blurriness), which is
    -- important for a nice crisp, 2D look
    love.graphics.setDefaultFilter('nearest', 'nearest')

    -- set the title of our application window
    love.window.setTitle('Pong')

    -- "seed" the RNG so that calls to random are always random
    -- use the current time, since that will vary on startup every time
    math.randomseed(os.time())

    -- initialize our nice-looking retro text fonts
    smallFont = love.graphics.newFont('font.ttf', 8)
    largeFont = love.graphics.newFont('font.ttf', 16)
    scoreFont = love.graphics.newFont('font.ttf', 32)
    love.graphics.setFont(smallFont)

    sounds ={ 
       ['paddle_hit'] = love.audio.newSource('paddle_hit.mp3', 'static'),
        ['point_scored'] = love.audio.newSource('point_scored.mp3', 'static'),
        ['wall_hit'] = love.audio.newSource('wall_hit.mp3', 'static'),
        ['win'] = love.audio.newSource('win.mp3', 'static'),
        
    }
    -- initialize window with virtual resolution
    push:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT, {
        fullscreen = false,
        resizable = true,
        vsync = true
    })

    -- initialize score variables, used for rendering on the screen and keeping
    -- track of the winner
    player1Score = 0
    player2Score = 0

    -- either going to be 1 or 2; whomever is scored on gets to serve the
    -- following turn
    servingPlayer = 1

    -- initialize player paddles and ball
    player1 = Paddle(10, 30, 5, 20)
    player2 = Paddle(VIRTUAL_WIDTH - 10, VIRTUAL_HEIGHT - 30, 5, 20)
    ball = Ball(VIRTUAL_WIDTH / 2 - 2, VIRTUAL_HEIGHT / 2 - 2, 4, 4)

    gameState = 'start'
end

--[[
    Runs every frame, with "dt" passed in, our delta in seconds 
    since the last frame, which LÖVE2D supplies us.
]]
function love.update(dt)
    if gameState == 'serve' then
        -- before switching to play, initialize ball's velocity based
        -- on player who last scored
        ball.dy = math.random(-50, 50)
        if servingPlayer == 1 then
            ball.dx = math.random(140, 200)
        else
            ball.dx = -math.random(140, 200)
        end
    elseif gameState == 'play' then
        -- detect ball collision with paddles, reversing dx if true and
        -- slightly increasing it, then altering the dy based on the position of collision
        if ball:collides(player1) then
            ball.dx = -ball.dx * 1.03
            ball.x = player1.x + 5

            sounds['paddle_hit']:play()

            -- keep velocity going in the same direction, but randomize it
            if ball.dy < 0 then
                ball.dy = -math.random(10, 150)
            else
                ball.dy = math.random(10, 150)
            end
        end
        if ball:collides(player2) then
            ball.dx = -ball.dx * 1.03
            ball.x = player2.x - 4

            sounds['paddle_hit']:play()

            -- keep velocity going in the same direction, but randomize it
            if ball.dy < 0 then
                ball.dy = -math.random(10, 150)
            else
                ball.dy = math.random(10, 150)
            end
        end

        -- detect upper and lower screen boundary collision and reverse if collided
        if ball.y <= 0 then
            ball.y = 0
            ball.dy = -ball.dy

            sounds['wall_hit']:play()

        end

        -- -4 to account for the ball's size
        if ball.y >= VIRTUAL_HEIGHT - 4 then
            ball.y = VIRTUAL_HEIGHT - 4
            ball.dy = -ball.dy

            sounds['wall_hit']:play()

        end
        
        -- if we reach the left or right edge of the screen, 
        -- go back to start and update the score
        if ball.x < 0 then
            servingPlayer = 1
            player2Score = player2Score + 1

            sounds['point_scored']:play()

            -- if we've reached a score of 10, the game is over; set the
            -- state to done so we can show the victory message
            if player2Score == 3 then
                winningPlayer = 2
                gameState = 'done'
            else
                gameState = 'serve'
                -- places the ball in the middle of the screen, no velocity
                ball:reset()
            end
        end

        if ball.x > VIRTUAL_WIDTH then
            servingPlayer = 2
            player1Score = player1Score + 1
            
            sounds['point_scored']:play()


            if player1Score == 3 then
                winningPlayer = 1
                gameState = 'done'
            else
                gameState = 'serve'
                ball:reset()
            end
        end
    end

    -- player 1 movement
    if love.keyboard.isDown('w') then
        player1.dy = -PADDLE_SPEED
    elseif love.keyboard.isDown('s') then
        player1.dy = PADDLE_SPEED
    else
        player1.dy = 0
    end

    -- player 2 movement
    if love.keyboard.isDown('up') then
        player2.dy = -PADDLE_SPEED
    elseif love.keyboard.isDown('down') then
        player2.dy = PADDLE_SPEED
    else
        player2.dy = 0
    end

    -- update our ball based on its DX and DY only if we're in play state;
    -- scale the velocity by dt so movement is framerate-independent
    if gameState == 'play' then
        ball:update(dt)
    end

    player1:update(dt)
    player2:update(dt)
end

--[[
    Keyboard handling, called by LÖVE2D each frame; 
    passes in the key we pressed so we can access.
]]
function love.keypressed(key)

    if key == 'escape' then
        love.event.quit()
    -- if we press enter during either the start or serve phase, it should
    -- transition to the next appropriate state
    elseif key == 'enter' or key == 'return' then
        if gameState == 'start' then
            gameState = 'serve'
        elseif gameState == 'serve' then
            gameState = 'play'
        elseif gameState == 'done' then
            -- game is simply in a restart phase here, but will set the serving
            -- player to the opponent of whomever won for fairness!
            gameState = 'serve'

            ball:reset()

            -- reset scores to 0
            player1Score = 0
            player2Score = 0

            -- decide serving player as the opposite of who won
            if winningPlayer == 1 then
                servingPlayer = 2
            else
                servingPlayer = 1
            end
        end
    end
end

--[[
    Called after update by LÖVE2D, used to draw anything to the screen, 
    updated or otherwise.
]]
function love.draw()

    push:apply('start')

    -- clear the screen with a specific color; in this case, a color similar
    -- to some versions of the original Pong
    love.graphics.clear(40/255, 45/255, 52/255, 255/255)

    love.graphics.setFont(smallFont)

    displayScore()

    if gameState == 'start' then
        love.graphics.setFont(smallFont)
        love.graphics.printf('Welcome to Pong!', 0, 10, VIRTUAL_WIDTH, 'center')
        love.graphics.printf('Press Enter to begin!', 0, 20, VIRTUAL_WIDTH, 'center')
    elseif gameState == 'serve' then
        love.graphics.setFont(smallFont)
        love.graphics.printf('Player ' .. tostring(servingPlayer) .. "'s serve!", 
            0, 10, VIRTUAL_WIDTH, 'center')
        love.graphics.printf('Press Enter to serve!', 0, 20, VIRTUAL_WIDTH, 'center')
    elseif gameState == 'play' then
        -- no UI messages to display in play
    elseif gameState == 'done' then
        -- UI messages
        love.graphics.setFont(largeFont)
        love.graphics.printf('Player ' .. tostring(winningPlayer) .. ' wins!',
            0, 10, VIRTUAL_WIDTH, 'center')
        love.graphics.setFont(smallFont)
        sounds['paddle_hit']:play()
        love.graphics.printf('Press Enter to restart!', 0, 30, VIRTUAL_WIDTH, 'center')
    end

    player1:render()
    player2:render()
    ball:render()

    displayFPS()

    push:apply('end')
end

--[[
    Renders the current FPS.
]]
function displayFPS()
    -- simple FPS display across all states
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0, 255, 0, 255)
    love.graphics.print('FPS: ' .. tostring(love.timer.getFPS()), 10, 10)
end

--[[
    Simply draws the score to the screen.
]]
function displayScore()
    -- draw score on the left and right center of the screen
    -- need to switch font to draw before actually printing
    love.graphics.setFont(scoreFont)
    love.graphics.print(tostring(player1Score), VIRTUAL_WIDTH / 2 - 50, 
        VIRTUAL_HEIGHT / 3)
    love.graphics.print(tostring(player2Score), VIRTUAL_WIDTH / 2 + 30,
        VIRTUAL_HEIGHT / 3)
end















-- Class = require 'class'
-- push = require 'push'

-- require 'Ball'
-- require 'Paddle'
-- --dimension de la fenetre
-- WINDOW_WIDTH = 1280
-- WINDOW_HEIGHT = 720

-- VIRTUAL_WIDTH = 432
-- VIRTUAL_HEIGHT = 243

-- PADDLE_SPEED = 200

-- --Runs when the game first starts up, only once; used to initialize the game.

-- function love.load()

    

--     love.graphics.setDefaultFilter('nearest', 'nearest')


--     love.window.setTitle('Prowebsa Pong')

--     math.randomseed(os.time())

--     smallFont = love.graphics.newFont('font.ttf', 8)
    
--     scoreFont = love.graphics.newFont('font.ttf', 32)

--     player1Score = 0
--     player2Score = 0

--     servingPlayer = math.random(2) == 1 and 1 or 2



--     -- player1Y = 30 
--     -- player2Y = VIRTUAL_HEIGHT -50

--     player1 = Paddle(10, 30, 5, 20)

--     player2 = Paddle(VIRTUAL_WIDTH - 10, VIRTUAL_HEIGHT - 30, 5, 20)

--     ball = Ball(VIRTUAL_WIDTH /2, -2, VIRTUAL_HEIGHT /2 -2, 4 ,4)


--     if servingPlayer == 1 then
--         ball.dx = 100
--     else
--         ball.dx = -100
--     end

--  --use nearest-neighbor filtering on upscaling and downscaling to prevent blurring of text
--  push:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT,{
--     fullscreen = false,
--     vsync = true,
--     resizable = false
-- } )

--     ballX = VIRTUAL_WIDTH /2 -2
--     ballY = VIRTUAL_HEIGHT /2 -2

--     ballDX = math.random(2) == 1 and  100 or -100
--     ballDY = math.random(- 50, 50) 

--     gameState = 'start'


   
-- end




-- function love.update(dt)
--     if gameState == 'serve' then

--         if ball.x <= 0 then
--             player2Score = player2Score + 1
--             servingPlayer = 1
--             ball:reset()
--             ball.dx = 100
--             gameState = 'serve' 
--         end

--         if ball.x >= VIRTUAL_WIDTH - 4 then
--             player1Score = player1Score + 1
--             servingPlayer = 2
--             ball:reset()
--             ball.dx = -100
--             gameState = 'serve'

--         end

--     if ball:collides (player1) then
--         --deflect ball to the right
--         ball.dx = -ball.dx * 1.03
--         ball.x = player1.x + 5
-- -- keep velocity going in the same direction, but randomize it

--         if ball.dy < 0 then
--             ball.dy = -math.random(10, 150)
--         else
--             ball.dy = math.random(10, 150)
--     end
-- end

--     if ball:collides(player2) then
--        --deflec ball to the left
--        ball.dx = -ball.dx * 1.03
--        ball.x = player2.x -4

--        if ball.dy < 0 then
--         ball.dy = -math.random(10, 150) 
--        else
--             ball.dy = math.random(10, 150)
--        end
--     end

--     if ball.y <= 0 then
--         --deflect the ball down
      
--         ball.dy = -ball.dy
--         ball.y = 0
       
--     end

--     if ball.y >= VIRTUAL_HEIGHT - 4 then
--        ball.y = VIRTUAL_HEIGHT -4
--        ball.dy = -ball.dy 
    
--     end


--     player1:update(dt)
--     player2:update(dt)
  
--     if love.keyboard.isDown('w') then
--         player1.dy = -PADDLE_SPEED
      
--     elseif love.keyboard.isDown('s') then
--         player1.dy = PADDLE_SPEED
--     else
--         player1.dy = 0
--     end

--     -- player 2 movement
--     if love.keyboard.isDown('up') then
--         player2.dy = -PADDLE_SPEED
         
--     elseif love.keyboard.isDown('down') then
--         player2.dy = PADDLE_SPEED
--     else
--         player2.dy = 0
--     end

--     if gameState == 'play' then
    
--         if ball.x <= 0 then
--             player2Score = player2Score + 1
--             ball:reset()
--             gameState = 'start'
--         end
        
--         if ball.x >= VIRTUAL_WIDTH -4 then
--             player1Score = player1Score + 1
--             ball:reset()
--             gameState = 'start'
--         end

--         ball:update(dt)
         
--     end
-- end



-- function love.keypressed(key)
--     if key == 'escape' then
--         love.event.quit()

--     elseif key == 'enter' or key == 'return' then
--         if gameState == 'start' then
--             gameState = 'serve'
--         elseif gameState =='serve' then
--             gameState = 'play'
        
    
--         end
--     end
-- end

-- function love.draw()
--     --begin rendering at virtual resolution
--     push:apply('start')

--     love.graphics.clear(40/255, 45/255, 52/255, 255/255)

--     -- draw welcome text toward the top of scren
--     -- love.graphics.setFont(smallFont)
--     -- if gameState == 'start' then
--     --     love.graphics.printf("Hello Start state", 0, 20, VIRTUAL_WIDTH, 'center')
--     -- elseif gameState == 'play' then
--     --     love.graphics.printf("Hello Play state", 0, 20, VIRTUAL_WIDTH, 'center')

--     -- end
--     love.graphics.setFont(smallFont)
    
--     if gameState == 'start' then
--     love.graphics.printf('Welcom to Pong!', 0, 20, VIRTUAL_WIDTH, 'center')
--     love.graphics.printf('Press Enter to Play!', 0, 32, VIRTUAL_WIDTH, 'center')
--     elseif gameState == 'serve' then
--         love.graphics.printf("Player " ..tostring(servingPlayer) .. "'s turn!", 0, 32, VIRTUAL_WIDTH, 'center')
--         love.graphics.printf("Press Enter to Serve!", 0, 32, VIRTUAL_WIDTH, 'center')


--     end

--     love.graphics.print(player1Score, VIRTUAL_WIDTH /2 -50, VIRTUAL_HEIGHT /3 )
--     love.graphics.print(player1Score, VIRTUAL_WIDTH /2 +30, VIRTUAL_HEIGHT /3 )

 
--     player1:render()
--     player2:render()
--         --render first paddle (left size)
--         --love.graphics.rectangle('fill', 10, player1Y, 5, 20)



--     --love.graphics.rectangle('fill', VIRTUAL_WIDTH -10, player2Y, 5, 20)


--     --render ball(center)
--     ball:render()

--     displayFPS()
    
    
--     --end rendering at virtual resolution
--     push:apply('end')
-- end

-- function displayFPS()
--     love.graphics.setColor(0, 1, 0, 1)
--     love.graphics.setFont(smallFont)
--     love.graphics.print('FPS' ..tostring(love.timer.getFPS()), 40, 20)
--     love.graphics.setColor(1,1,1,1)
-- end
-- end



















