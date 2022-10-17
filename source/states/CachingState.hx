package states;
#if sys
import flixel.addons.ui.FlxUIState;
import flixel.FlxState;
import sys.thread.Thread;
import flixel.graphics.FlxGraphic;
import flixel.FlxG;
import flixel.util.FlxColor;
import flixel.text.FlxText;
import lime.app.Application;
import Discord.DiscordClient;
import flixel.FlxSprite;
import Options;
import flixel.ui.FlxBar;
import openfl.display.BitmapData;
import Sys;
import sys.FileSystem;
import flixel.util.FlxTimer;
import flixel.addons.transition.FlxTransitionSprite.GraphicTransTileDiamond;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.transition.TransitionData;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import openfl.Assets;
import openfl.utils.AssetType;
import openfl.media.Sound;
import ui.*;
using StringTools;

class CachingState extends FlxUIState {
  var finishState:FlxState;
  var icon:FlxSprite;
  var bg:FlxSprite;
  var bar:FlxBar;
  var barBG:FlxSprite;
  var loaded:Float = 0;
  var toLoad:Float = 0;
  var isLoaded:Bool=false;
  var threadActive:Bool=true;

  var imagesLoaded:Int = 0;
  var soundsLoaded:Int = 0;
  var images:Array<String> = [];
  var sounds:Array<String> = [];

  var recentlyLoadedImg='';
  var recentlyLoadedSnd='';

  var loadImage:Thread;
  var loadSound:Thread;

  var loadingText:FlxText;
  var percentText:FlxText;

  public static var cache:Map<String,FlxGraphic> = new Map<String,FlxGraphic>();

  override function create(){
    super.create();
    FlxG.autoPause=false;
    bg = new FlxSprite().loadGraphic(Paths.image("loadingBG","preload"));
    bg.setGraphicSize(Std.int(bg.width*.85));
    bg.updateHitbox();
    bg.screenCenter(XY);
    bg.antialiasing=true;
    add(bg);

    barBG = new FlxSprite().loadGraphic(Paths.image("barBackground","preload"));
    barBG.setGraphicSize(Std.int(barBG.width));
    barBG.updateHitbox();
    barBG.screenCenter(XY);
    barBG.y += 200;
    barBG.antialiasing=true;
    add(barBG);

    icon = new FlxSprite();
    icon.frames = Paths.getSparrowAtlas("andromedaLogoBumpin","preload");
    icon.setGraphicSize(Std.int(icon.width*.8));
    icon.updateHitbox();
    icon.animation.addByPrefix("idle","logo bumpin",24,true);
    icon.animation.play("idle",true);
    icon.antialiasing=true;
    icon.screenCenter(X);
    add(icon);

    FlxG.sound.playMusic(Paths.music('old/title'));
    
    var list = Assets.list();

    if(EngineData.options.cachePreload){
    	 var imageList = list.filter(text -> text.contains('assets/images'));
        //imageList = imageList.split(':')[1]; // idk about dpes it needed or no, so is commented for now
        for (file in imageList)
        {
          if(file.endsWith(".png")){ // TODO: recursively go through all directories
            images.push('${file}');
          }
        }
    }

    if(EngineData.options.cacheCharacters){
        var charImageList = list.filter(text -> text.contains('assets/characters/images'));
        //charImageList = charImageList.split(':')[1]; // idk about dpes it needed or no, so is commented for now
        for (file in charImageList)
        {
          if(file.endsWith(".png")){
            images.push('${file}');
          }
        }
    }
    if(EngineData.options.cacheSongs){
        var songsList = list.filter(text -> text.contains('assets/songs'));
            for (file in songsList)
            {
              if(file.endsWith('.mp3') || file.endsWith('.ogg')){
                sounds.push('${file}');
              }
            }
      }
      
      
      var musicList = list.filter(text -> text.contains('assets/music'));
        for (file in musicList)
        {
          if(file.endsWith('.mp3') || file.endsWith('.ogg')){
            sounds.push('${file}');
          }
        }
        
        var sharedMusicList = list.filter(text -> text.contains('assets/shared/music'));
        for (file in sharedMusicList)
        {
          if(file.endsWith('.mp3') || file.endsWith('.ogg')){
            sounds.push('${file}');
          }
        }

    if(EngineData.options.cacheSounds){
      var soundList = list.filter(text -> text.contains('assets/sounds'));
        for (file in soundList)
        {
          if(file.endsWith('.mp3') || file.endsWith('.ogg')){
            sounds.push('${file}');
          }
        }
      var sharedSoundList = list.filter(text -> text.contains('assets/shared/sounds'));
        for (file in sharedSoundList)
        {
          if(file.endsWith('.mp3') || file.endsWith('.ogg')){
            sounds.push('${file}');
          }
        }
    }


    toLoad = images.length+sounds.length;
    if(toLoad<=0){
      InitState.initTransition();
      transIn = FlxTransitionableState.defaultTransIn;
      transOut = FlxTransitionableState.defaultTransOut;
      FlxG.switchState(finishState);
      return;
    }
    bar = new FlxBar(barBG.x + 4, barBG.y + 4, LEFT_TO_RIGHT, Std.int(barBG.width - 8), Std.int(barBG.height - 8), this,
      'loaded', 0, toLoad);
    bar.createFilledBar(0xFF808080, 0xFF4CFF00);
    add(bar);

    loadingText = new FlxText(barBG.x, barBG.y + 75, 0, "", 20);
    loadingText.setFormat(null, 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		loadingText.scrollFactor.set();
		add(loadingText);

    percentText = new FlxText(barBG.x + barBG.width/2, barBG.y, 0, "", 20);
    percentText.setFormat(null, 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    percentText.scrollFactor.set();
    add(percentText);

    loadImage = Thread.create(()->{
      while (true)
      {
        if (!threadActive)
        {
          trace("Killing thread");
          return;
        }
        var msg:Null<String> = Thread.readMessage(false);
        if(msg!=null && msg!=recentlyLoadedImg){
          recentlyLoadedImg=msg;
          var id = msg.replace(".png","");
          if (msg.contains('/characters/') && !msg.startsWith('characters:')) {
                  msg = 'characters:' + msg;
          }
          var data:BitmapData = Assets.getBitmapData(msg);
          var graphic = FlxG.bitmap.add(data,true,id);
          graphic.persist=true;
          graphic.destroyOnNoUse=false;
          cache.set(id,graphic);
          trace("loaded " + msg);
          loaded++;
          imagesLoaded++;
        }
      }
    });
    loadSound = Thread.create(()->{
      while (true)
      {
        if (!threadActive)
        {
          trace("Killing thread");
          return;
        }
        var msg:Null<String> = Thread.readMessage(false);
        if(msg!=null && msg!=recentlyLoadedSnd){
          recentlyLoadedSnd=msg;
          if (msg.contains('/songs/') && !msg.startsWith('songs:')) {
                  msg = 'songs:' + msg;
          }
          if (msg.contains('/shared/') && !msg.startsWith('shared:')) {
                  msg = 'shared:' + msg;
          }
          if(Assets.exists(msg, AssetType.SOUND) || Assets.exists(msg, AssetType.MUSIC)){ // https://github.com/HaxeFlixel/flixel/blob/master/flixel/system/frontEnds/SoundFrontEnd.hx
            var sound = FlxG.sound.cache(msg);
            CoolUtil.cacheSound(msg,sound);
          }else{
            CoolUtil.cacheSound(msg,Assets.getSound(msg));
          }

          trace("loaded " + msg);
          loaded++;
          soundsLoaded++;
        }
      }
    });


  }

  override function update(elapsed:Float){
    if(loaded<toLoad){
      if(imagesLoaded<images.length){
        var file = images[imagesLoaded];
        if(file!=recentlyLoadedImg){
          loadImage.sendMessage(file);
          loadingText.text = 'Loading ${file} (${loaded}/${toLoad})';
        }
      }else if(soundsLoaded<sounds.length){
        var file = sounds[soundsLoaded];
        if(file!=recentlyLoadedSnd){
          loadSound.sendMessage(file);
          loadingText.text = 'Loading ${file} (${loaded}/${toLoad})';
        }
      }
    }else if(loaded==toLoad && !isLoaded){
      loadingText.text = 'Loaded!';
      isLoaded=true;
      threadActive=false;
      if (FlxG.sound.music != null)
      {
        FlxG.sound.music.stop();
      }
      FlxG.camera.flash(FlxColor.WHITE, 2, null, true);
      FlxG.sound.play(Paths.sound('titleShoot'), 0.7);

      trace("Loaded!");

      new FlxTimer().start(5, function(tmr:FlxTimer)
      {
        InitState.initTransition();
        transIn = FlxTransitionableState.defaultTransIn;
        transOut = FlxTransitionableState.defaultTransOut;
        FlxG.switchState(finishState);
      });
    }

    percentText.text = '${Math.floor((loaded/toLoad)*100)}%';
    percentText.x = barBG.x + barBG.width/2;
    loadingText.screenCenter(X);
    super.update(elapsed);
  }
  public function new(state:FlxState){
    super();
    finishState=state;
  }
}
#end
