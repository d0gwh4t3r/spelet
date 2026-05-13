require 'ruby2d' # importerar ruby2d biblioteket som hanterar grafik och fönster

# Fönsterinställningar
set width: 940, height: 580, title: "Loyer Bird", fps_cap: 60

# Konstanter för spelet
GROUND_Y   = 540  # var marken är
GRAVITY    = 0.5  # hur snabbt fågeln faller
JUMP       = -9   # hoppkraft (minus = uppåt)
PIPE_GAP   = 160  # glapp mellan rören
PIPE_SPEED = 3    # hastighet på hinder


class Bird
  attr_accessor :velocity, :radius

  def initialize
    @img = Image.new("123.png", x: 134, y: 284, width: 40, height: 40)
    @velocity = 0
    @base_y = 300
    @radius = 14
    @small_timer = 0
  end

  # uppdaterar gravitation och position
  def update
    @velocity += GRAVITY
    @base_y += @velocity
    @img.y = @base_y - @radius

    # om fågeln är liten minskar timern
    if @small_timer > 0
      @small_timer -= 1
      grow_normal if @small_timer == 0
    end
  end

  # hoppa upp
  def jump
    @velocity = JUMP
  end

  def small?
    @small_timer > 0
  end

  # gör fågeln mindre
  def shrink
    @img.width = @img.height = 20
    @radius = 7
    @small_timer = 180
  end

  # tillbaka till normal storlek
  def grow_normal
    @img.width = @img.height = 40
    @radius = 14
  end

  # reset vid game over
  def reset
    @base_y = 300
    @img.x = 134
    @img.y = @base_y - 16
    @img.width = @img.height = 40
    @radius = 14
    @velocity = 0
    @small_timer = 0
  end

  # fågelns mittpunkt X
  def x
    @img.x + @img.width / 2
  end

  # fågelns mittpunkt Y
  def y
    @img.y + @img.height / 2
  end
end


class Pipe
  attr_reader :x, :passed

  def initialize
    top_h = rand(80..300)   # slumpa höjd
    bot_y = top_h + PIPE_GAP

    @x = 940
    @top_h = top_h
    @bot_y = bot_y
    @passed = false

    # övre och undre rör
    @top = Image.new("1234.png", x: @x, y: 0, width: 150, height: top_h)
    @bot = Image.new("1234.png", x: @x, y: bot_y, width: 150, height: 580 - bot_y)
  end

  # flytta röret åt vänster
  def update
    @x -= PIPE_SPEED
    @top.x = @bot.x = @x
  end

  def off_screen?
    @x < -100
  end

  def mark_passed
    @passed = true
  end

  def remove
    @top.remove
    @bot.remove
  end

  # kollar krock med fågel
  def collision?(bird)
    if bird.x + bird.radius > @x + 45 && bird.x - bird.radius < @x + 105
      bird.y - bird.radius < @top_h - 15 || bird.y + bird.radius > @bot_y + 20
    end
  end
end


class BouncingSpike
  attr_reader :x, :active

  def initialize
    @x = 1000
    @y = rand(80..460)
    @active = true
    @dir = 1
    @speed = rand(2..4)

    @img = Image.new("spike.png", x: @x - 30, y: @y - 30, width: 60, height: 60, z: 5)
  end

  def update
    @x -= PIPE_SPEED
    @y += @speed * @dir

    # byter riktning upp/ner
    @dir = -@dir if @y < 80 || @y > 460

    @img.x = @x - 30
    @img.y = @y - 30
  end

  # krock med fågel (cirkel-koll)
  def collision?(bird)
    Math.sqrt((@x - bird.x)**2 + (@y - bird.y)**2) < bird.radius + 20
  end

  def off_screen?
    @x < -50
  end

  def remove
    @img.remove
    @active = false
  end
end


class ShrinkPowerup
  attr_reader :x, :active

  def initialize
    @x = 1000
    @y = rand(80..460)
    @active = true

    @img = Image.new("powerup.png", x: @x - 25, y: @y - 25, width: 50, height: 50, z: 5)
  end

  def update
    @x -= PIPE_SPEED
    @img.x = @x - 25
  end

  # om fågeln plockar upp
  def collect?(bird)
    Math.sqrt((@x - bird.x)**2 + (@y - bird.y)**2) < bird.radius + 25
  end

  def off_screen?
    @x < -50
  end

  def remove
    @img.remove
    @active = false
  end
end

# ===== SCORE =====
class ScoreManager
  attr_reader :score, :highscore

  def initialize
    @score = 0
    @highscore = 0

    @text = Text.new("0", x: 460, y: 50, size: 40, color: 'white', z: 10)
    @hs_text = Text.new("BÄST: 0", x: 10, y: 10, size: 22, color: [1, 0.85, 0, 1], z: 10)
  end

  # +1 poäng
  def add_point
    @score += 1
    @text.text = @score.to_s
    @text.x = 460 - @score.to_s.length * 12

    # uppdatera highscore
    if @score > @highscore
      @highscore = @score
      @hs_text.text = "BÄST: #{@highscore}"
    end
  end

  # reset score
  def reset
    @score = 0
    @text.text = "0"
    @text.x = 460
  end
end


class Game
  attr_reader :state

  def initialize
    @state = :start

    # startskärm
    @start_screen = Image.new("startbild2.png", x: 0, y: 0, width: 940, height: 580)

    @start_button = Rectangle.new(x: 330, y: 370, width: 260, height: 60, color: [1,1,1,0.15])
    @start_label  = Text.new("Tryck SPACE för att starta", x: 305, y: 490, size: 22, color: [1,1,1,0.9])

    @background = Image.new("back.png", x: 0, y: 0, width: 940, height: 580, z: -1)

    @bird = Bird.new
    @pipes = []
    @spikes = []
    @powerups = []

    @spawn_timer = 0
    @spike_timer = 0
    @powerup_timer = 0

    @game_over = false
    @score_mgr = ScoreManager.new

    @small_text = nil
    @gameover_img = nil
  end

  # uppdaterar spelet varje frame
  def update
    return if @state == :start || @game_over

    @bird.update

    # visar text om fågeln är liten
    if @bird.small?
      @small_text ||= Text.new("LITEN!", x: 60, y: 50, size: 22, color: [0.2,0.9,0.4,1], z: 10)
    else
      @small_text&.remove
      @small_text = nil
    end

    # spawn rör
    @spawn_timer += 1
    if @spawn_timer > 90
      @pipes << Pipe.new
      @spawn_timer = 0
    end

    # spawn spikes
    @spike_timer += 1
    if @spike_timer > 120
      @spikes << BouncingSpike.new
      @spike_timer = 0
    end

    # spawn powerups
    @powerup_timer += 1
    if @powerup_timer > 200
      @powerups << ShrinkPowerup.new
      @powerup_timer = 0
    end

    # uppdatera pipes
    @pipes.each do |pipe|
      pipe.update
      @game_over = true if pipe.collision?(@bird)
    end

    # uppdatera spikes
    @spikes.each do |s|
      s.update
      @game_over = true if s.collision?(@bird)
    end

    # uppdatera powerups
    @powerups.each do |p|
      p.update
      if p.collect?(@bird)
        p.remove
        @bird.shrink
      end
    end

    # game over om fågeln åker utanför
    @game_over = true if @bird.y < 40 || @bird.y > 540

    # visa game over bild
    if @game_over && @gameover_img.nil?
      @gameover_img = Image.new("gameover.png", x: 0, y: 0, width: 940, height: 580, z: 20)
    end
  end

  # hopp eller restart
  def jump_or_restart
    if @state == :start
      @state = :playing
    elsif @game_over
      reset_game
    else
      @bird.jump
    end
  end

  # reset allt
  def reset_game
    @pipes.each(&:remove)
    @spikes.each(&:remove)
    @powerups.each(&:remove)

    @pipes.clear
    @spikes.clear
    @powerups.clear

    @bird.reset
    @score_mgr.reset

    @game_over = false
  end

  # klick på startknapp
  def click_on_start_button?(mx, my)
    mx.between?(@start_button.x, @start_button.x + @start_button.width) &&
    my.between?(@start_button.y, @start_button.y + @start_button.height)
  end
end

# start spelet
game = Game.new

update { game.update }

on(:key_down) { |e| game.jump_or_restart if e.key == 'space' }

on(:mouse_down) do |e|
  game.jump_or_restart if game.state == :start && game.click_on_start_button?(e.x, e.y)
end

show