/* Evaluated in an existing YouTube Music page; no navigation or playback startup. */
(() => {
  const request = __REQUEST__;
  const clean = s => typeof s === 'string' ? s.trim() : '';
  const text = x => clean(typeof x === 'string' ? x : x?.simpleText || x?.runs?.map(r => r.text).join(''));
  const image = x => x?.thumbnails?.at(-1)?.url || '';
  const bar = document.querySelector('ytmusic-player-bar');
  const video = document.querySelector('video');
  const queue = document.querySelector('ytmusic-player-queue');
  const rows = [...(queue?.querySelectorAll('ytmusic-player-queue-item, ytmusic-player-queue-item-renderer') || [])];
  const metadata = navigator.mediaSession?.metadata;
  const unwrap = x => x?.playlistPanelVideoWrapperRenderer?.primaryRenderer?.playlistPanelVideoRenderer || x?.playlistPanelVideoRenderer || x || {};
  const entries = Array.isArray(queue?.data) ? queue.data.map(unwrap) : [];
  const watch = d => d?.navigationEndpoint?.watchEndpoint || {};
  const videoId = d => d?.videoId || watch(d).videoId || '';
  const setId = d => d?.playlistSetVideoId || watch(d).playlistSetVideoId || '';
  const items = entries.map((d, index) => ({
    id: `${index}:${setId(d) || videoId(d)}`,
    title: text(d.title), artist: text(d.shortBylineText || d.longBylineText),
    artUrl: image(d.thumbnail), current: !!d.selected, index
  }));
  // Match the canonical entry to an actual rendered row, never to an autoplay extra.
  const findRow = entry => {
    const endpoint = watch(entry), id = videoId(entry), set = setId(entry);
    if (!id && !set) return null;
    const matches = rows.filter(row => {
      const d = unwrap(row.data);
      const rEndpoint = watch(d);
      if (set ? setId(d) !== set : videoId(d) !== id) return false;
      if (endpoint.index != null && rEndpoint.index != null && endpoint.index !== rEndpoint.index) return false;
      return true;
    });
    return matches.length === 1 ? matches[0] : null;
  };
  const playerData = document.getElementById?.('movie_player')?.getVideoData?.() || {};
  const playerId = clean(playerData.video_id);
  const selectedIndex = items.findIndex(item => item.current);
  const matchingIndex = playerId ? entries.findIndex(d => videoId(d) === playerId) : -1;
  const currentIndex = playerId ? (selectedIndex >= 0 && videoId(entries[selectedIndex]) === playerId ? selectedIndex : matchingIndex) : selectedIndex;
  const current = items[currentIndex];
  const title = clean(playerData.title) || current?.title || clean(bar?.querySelector('.title')?.textContent) || clean(metadata?.title);
  const artist = clean(playerData.author) || current?.artist || clean(bar?.querySelector('.byline')?.textContent) || clean(metadata?.artist);
  // Media Session may lag behind the player while a track is changing.
  const metadataMatches = clean(metadata?.title) === title;
  const album = metadataMatches ? clean(metadata?.album) : '';
  for (const [i, item] of items.entries()) item.current = i === currentIndex;
  const button = name => bar?.querySelector(name);
  const next = button('.next-button, [aria-label="Next"]');
  const previous = button('.previous-button, [aria-label="Previous"]');
  const enabled = el => !!el && !el.disabled && !el.hasAttribute('disabled') && el.getAttribute('aria-disabled') !== 'true' && !el.querySelector('button:disabled, [aria-disabled="true"]');
  const shuffleButton = button('.shuffle');
  const repeatButton = button('.repeat');
  const shuffle = typeof bar?.shuffleOn === 'boolean' ? bar.shuffleOn : !!bar?.shuffleEnabled;
  const repeatMode = String(bar?.repeatMode || '').toUpperCase();
  const repeat = ['ONE', 'REPEAT_ONE', 'SINGLE'].includes(repeatMode) ? 'one' : ['ALL', 'REPEAT_ALL', 'LOOP'].includes(repeatMode) ? 'all' : 'off';
  const canShuffle = enabled(shuffleButton) && bar?.isShuffleDisabled !== true &&
    (typeof bar?.shuffleOn === 'boolean' || typeof bar?.shuffleEnabled === 'boolean');
  const canRepeat = enabled(repeatButton) && bar?.isRepeatButtonDisabled !== true && !!repeatMode;
  const queueId = clean(watch(entries[currentIndex]).playlistId);
  const duration = Number.isFinite(video?.duration) ? video.duration : 0;
  const state = {available: !!(bar && video && (title || items.length)), source:'youtube-music', title, artist, artUrl: current?.artUrl || (metadataMatches ? metadata?.artwork?.at(-1)?.src : '') || bar?.querySelector('img')?.src || '', playing: !!video && !video.paused && !video.ended, position: Number.isFinite(video?.currentTime) ? video.currentTime : 0, duration, album, currentIndex, queueId, shuffle, repeat, canShuffle, canRepeat, visible: document.visibilityState === 'visible', canNext:enabled(next), canPrevious:enabled(previous), canSeek:!!video && duration > 0, queue:items};
  if (!request || request.command === 'state') return state;
  if (!state.available) throw new Error('Music session unavailable');
  switch (request.command) {
    case 'playPause': case 'play': case 'pause': {
      if (request.command === 'play' && state.playing || request.command === 'pause' && !state.playing) break;
      const toggle = button('#play-pause-button, .play-pause-button');
      if (!enabled(toggle)) throw new Error('Playback control unavailable');
      toggle.click(); break;
    }
    case 'shuffle': if (!canShuffle) throw new Error('Shuffle unavailable'); shuffleButton.click(); break;
    case 'repeat': if (!canRepeat) throw new Error('Repeat unavailable'); repeatButton.click(); break;
    case 'next': if (!enabled(next)) throw new Error('Next unavailable'); next.click(); break;
    case 'previous': if (!enabled(previous)) throw new Error('Previous unavailable'); previous.click(); break;
    case 'seek': if (!state.canSeek || request.position < 0 || request.position > duration) throw new Error('Invalid seek position'); video.currentTime = request.position; break;
    case 'select': {
      const item = items[request.index];
      if (!item || item.id !== request.id) throw new Error('Queue changed');
      const row = findRow(entries[request.index]);
      if (!row) throw new Error('Queue row unavailable or ambiguous');
      const target = row.querySelector('ytmusic-play-button-renderer') || row;
      target.click(); break;
    }
    default: throw new Error('Unknown command');
  }
  return {ok:true};
})()
