package snake

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

WINDOW_SIZE :: 1000
GRID_WIDTH :: 20
CELL_SIZE :: 16
CANVAS_SIZE :: GRID_WIDTH * CELL_SIZE
TICK_RATE :: 0.15
Vec2i :: [2]int
MAX_SNAKE_LENGTH :: GRID_WIDTH*GRID_WIDTH


snake: [MAX_SNAKE_LENGTH]Vec2i
snake_length: int
tick_timer: f32 = TICK_RATE
snake_head_position: Vec2i
move_direction : Vec2i
game_over: bool
food_pos: Vec2i
best_score: int
shake_offset: Vec2i = {5, 5}
shake_timer : f32
shake_amount: f32



place_food :: proc() {
    occupied: [GRID_WIDTH][GRID_WIDTH]bool

    for i in 0..<snake_length {
        occupied[snake[i].x][snake[i].y] = true
    }

    free_cells := make([dynamic]Vec2i, context.temp_allocator)

    for x in 0..<GRID_WIDTH {
        for y in 0..<GRID_WIDTH {
            append(&free_cells, Vec2i{x, y})
        }
    }

    if len(free_cells) > 0 {
        random_cell_index := rl.GetRandomValue(0, i32(len(free_cells) - 1))
        food_pos = free_cells[random_cell_index]
    }
}

restart :: proc() {

    start_head_pos := Vec2i {GRID_WIDTH/2, GRID_WIDTH/2}
    snake[0] = start_head_pos
    snake[1] = start_head_pos - {0,1}
    snake[2] = start_head_pos - {0,2}
    snake_length = 3
    move_direction = {0, 1}
    game_over = false
    place_food()
}

main :: proc() {
    icon := rl.LoadImage("assets/head.png")

    rl.SetConfigFlags({.VSYNC_HINT})
    rl.HideCursor()
    rl.InitWindow(WINDOW_SIZE, WINDOW_SIZE, "Snake Game with Odin")
    rl.SetWindowIcon(icon)
    rl.InitAudioDevice()

    restart()

    food_sprite := rl.LoadTexture("assets/food.png")
    head_sprite := rl.LoadTexture("assets/head.png")
    body_sprite := rl.LoadTexture("assets/body.png")
    tail_sprite := rl.LoadTexture("assets/tail.png")

    eat_sound := rl.LoadSound("assets/eat.wav")
    game_over_sound := rl.LoadSound("assets/game-over.mp3")
    game_music := rl.LoadMusicStream("assets/retro.mp3")

    rl.PlayMusicStream(game_music)


    for !rl.WindowShouldClose() {

        rl.UpdateMusicStream(game_music)

        if rl.IsKeyDown(.UP) {
            move_direction = {0, -1}
        }
        if rl.IsKeyDown(.DOWN) {
            move_direction = {0, 1}
        }
        if rl.IsKeyDown(.LEFT) {
            move_direction = {-1, 0}
        }
        if rl.IsKeyDown(.RIGHT) {
            move_direction = {1, 0}
        }

        if game_over {
            shake_timer -= rl.GetFrameTime()

            if rl.IsKeyPressed(.ENTER) {
                restart()
                rl.PlayMusicStream(game_music)

            }
        } else {
            tick_timer -= rl.GetFrameTime()

        }

        if shake_timer >= 0 {
            shake_amount = math.sin_f32(f32(10*shake_offset.x)) + shake_timer

        }

        if tick_timer <= 0 {
            next_part_pos := snake[0]
            snake[0] = snake[0] + move_direction
            head_pos := snake[0]

            //TODO: optimize this mess !
            if head_pos.x < 0 || head_pos.y < 0 || head_pos.x > GRID_WIDTH || head_pos.y > GRID_WIDTH {
                game_over = true
                rl.PlaySound(game_over_sound)
            }


            for i in 1..<snake_length {
                cur_pos := snake[i]
                if cur_pos == head_pos {
                    if snake[0] != snake[1] {
                        game_over = true
                        rl.PlaySound(game_over_sound)
                    }
                }
                snake[i] = next_part_pos
                next_part_pos = cur_pos
            }

            if head_pos == food_pos {
                snake_length += 1
                snake[snake_length - 1] = next_part_pos
                place_food()
                rl.PlaySound(eat_sound)
            }

            tick_timer += TICK_RATE
        }

        rl.BeginDrawing()
        rl.ClearBackground({76, 53, 83, 255})

        camera := rl.Camera2D {
            zoom = f32(WINDOW_SIZE) / CANVAS_SIZE,

        }

        rl.BeginMode2D(camera)

        rl.DrawTextureV(food_sprite, {f32(food_pos.x), f32(food_pos.y)}*CELL_SIZE, rl.WHITE)

        for i in 0..<snake_length {
            part_sprite := body_sprite
            dir: Vec2i

            if i == 0 {
                part_sprite = head_sprite
                dir = snake[i] - snake[i+1]
            } else if i == snake_length -1 {
                part_sprite = tail_sprite
                dir = snake[i-1] - snake[i]
            } else {
                dir = snake[i-1] - snake[i]
            }

            rot := math.atan2(f32(dir.y), f32(dir.x)) * math.DEG_PER_RAD

            source := rl.Rectangle {
                0, 0,
                f32(part_sprite.width), f32(part_sprite.height)
            }

            correct :f32 = CELL_SIZE * 0.5

            dest := rl.Rectangle {
                f32(snake[i].x)*CELL_SIZE + correct,
                f32(snake[i].y)*CELL_SIZE + correct,
                CELL_SIZE,
                CELL_SIZE
            }

            rl.DrawTexturePro(part_sprite, source, dest, { CELL_SIZE, CELL_SIZE } * 0.5, rot, rl.WHITE)
        }

        score := snake_length -3
        if score > best_score {
            best_score = score
        }
        best_score_str := fmt.ctprintf("Best Score: %v", best_score)
        score_str := fmt.ctprintf("Your Score: %v", score)
        rl.DrawText(score_str, 4, CANVAS_SIZE - 14, 10, rl.GRAY)

        fps := f16(rl.GetFPS())
        fps_str:= fmt.ctprintf("FPS: %v", fps)
        rl.DrawText(fps_str, CANVAS_SIZE - 50, CANVAS_SIZE - 14, 10, rl.BLACK)

        if game_over {
            rl.StopMusicStream(game_music)
            rl.DrawText("Game Over !", 4, 4, 25, rl.RED)
            rl.DrawText("Press Enter to play again", 4, 30, 15, rl.BLACK)
            rl.DrawText(best_score_str, 10, 50, 13, rl.BLUE)
        }

        rl.EndMode2D()
        rl.EndDrawing()
        free_all(context.temp_allocator)
    }

    rl.UnloadTexture(food_sprite)
    rl.UnloadTexture(head_sprite)
    rl.UnloadTexture(body_sprite)
    rl.UnloadTexture(tail_sprite)

    rl.UnloadSound(eat_sound)
    rl.UnloadSound(game_over_sound)

    rl.UnloadMusicStream(game_music)

    rl.CloseAudioDevice()
    rl.CloseWindow()
}
