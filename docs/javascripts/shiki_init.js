// Wir nutzen hier jsdelivr, das ist oft stabiler für dynamische Imports als esm.sh
import { getHighlighter } from 'https://cdn.jsdelivr.net/npm/shiki@1.0.0/+esm';

(async () => {
  try {
    const style = document.createElement('style');
    style.innerHTML = `
      /* 1. Basis-Setup für Code und Zähler */
      html .md-typeset pre.shiki code { 
        background-color: transparent !important; 
        background: transparent !important;
        counter-reset: step var(--start-line, 0); 
      }
      
      html .md-typeset pre.shiki {
        border: none !important;
        margin: 0 !important; /* Margin wird nun vom Container gesteuert */
        border-radius: 0 0 6px 6px !important; /* Unten abrunden (für Blöcke mit Header) */
      }

      /* --- NEU: Wenn es KEINEN Header gibt, runden wir oben UND unten ab --- */
      html .md-typeset .shiki-container.no-header pre.shiki {
        border-radius: 6px !important; 
      }

      /* 2. Zeilen-Setup */
      html .md-typeset pre.shiki .line {
        display: inline-block;
        width: 100%;
      }

      /* 3. Zeilennummern */
      html .md-typeset pre.shiki .line::before {
        content: counter(step);
        counter-increment: step;
        width: 1.5rem;
        margin-right: 1.5rem;
        display: inline-block;
        text-align: right;
        color: #75715E;
        user-select: none;
      }

      /* --- Container und Header --- */
      .shiki-container {
        position: relative;
        background: #272822; /* Monokai Hintergrund */
        border-radius: 6px;
        margin-bottom: 1.5em;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
      }

      /* Die neue Kopfzeile für Titel und Link */
      .shiki-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        background: #252225; /* Etwas dunkler als der Code-Hintergrund */
        padding: 0.4rem 0.8rem;
        border-bottom: 1px solid #3e323d;
        border-radius: 6px 6px 0 0; /* Oben abrunden */
      }

      html .md-typeset .shiki-header .shiki-title,
      html .md-typeset a.shiki-title {
        color: #ffffff !important; /* Erzwingt unser Monokai-Grün */
        font-family: monospace;
        font-size: 0.85em;
        text-decoration: none;
        display: flex;
        align-items: center;
        gap: 0.4rem;
      }

      html .md-typeset a.shiki-title:hover {
        text-decoration: underline !important;
        color: #e6a774 !important; /* Wechselt zu Monokai-Gelb */
      }

      /* --- Copy Button Styling --- */
      .copy-button {
        background: rgba(117, 113, 94, 0.2);
        border: 1px solid rgba(117, 113, 94, 0.4);
        color: #f8f8f2;
        border-radius: 4px;
        cursor: pointer;
        padding: 0.3rem 0.4rem;
        display: flex;
        align-items: center;
        justify-content: center;
        transition: all 0.2s ease;
        z-index: 10;
      }
      
      /* Wenn es KEINEN Header gibt, positionieren wir absolut */
      .shiki-container.no-header .copy-button {
        position: absolute;
        top: 0.5rem;
        right: 0.5rem;
      }

      .copy-button:hover {
        background: rgba(117, 113, 94, 0.6);
      }
      
      .copy-button svg {
        width: 16px;
        height: 16px;
      }
      
      /* Hover-Effekt für die Zeilen-Verlinkung */
      html .md-typeset pre.shiki .line.is-hovered {
        background-color: rgba(255, 255, 255, 0.1);
        border-left: 3px solid #a6e22e;
        padding-left: 5px;
        margin-left: -8px; /* Kompensiert den Border */
      }
    `;
    document.head.appendChild(style);

    console.log("Schritt 1: Lade eigene Grammatik...");
    // WICHTIG: Passe den Dateipfad an, falls noetig
    const response = await fetch('/extra/highlighting/lex.tmGrammar.json');
    if (!response.ok) throw new Error("Grammatik nicht gefunden!");
    
    const myLangGrammar = await response.json();
    const myLang = { ...myLangGrammar, name: 'mylang' };

    console.log("Schritt 2: Initialisiere Shiki aus dem Web...");
    const highlighter = await getHighlighter({
      themes: ['monokai', 'monokai'], 
      langs: ['javascript', 'python', 'json', 'bash', myLang] 
    });

    console.log("Schritt 3: Wende Farben auf Code-Blöcke an...");
    const codeBlocks = document.querySelectorAll('pre code');
    
    codeBlocks.forEach((block) => {
      const langClass = Array.from(block.classList).find(c => c.startsWith('language-'));
      if (!langClass) return;

      let startLine = 1;
      const startClass = Array.from(block.classList).find(c => c.startsWith('start-'));
      if (startClass) {
        startLine = parseInt(startClass.replace('start-', ''), 10);
      }

      const lang = langClass.replace('language-', '');
      const code = block.textContent;
      
      // Titel und Link aus Markdown-Attributen auslesen
      // Wir prüfen den `code` Block und den übergeordneten `pre` Block (falls MkDocs das Attribut verschiebt)
      const titleText = block.getAttribute('title') || block.parentElement.getAttribute('title');
      const titleUrl = block.getAttribute('data-url') || block.parentElement.getAttribute('data-url');

      try {
        let html = highlighter.codeToHtml(code, {
          lang: lang,
          themes: { light: 'monokai', dark: 'monokai' }
        });

        const counterStart = startLine - 1;
        html = html.replace('<pre ', `<pre style="--start-line: ${counterStart};" `);

        // Container erstellen
        const wrapper = document.createElement('div');
        wrapper.className = 'shiki-container';
        
        // Copy-Button erstellen
        const copyBtn = document.createElement('button');
        copyBtn.className = 'copy-button';
        copyBtn.title = "Code kopieren";
        
        const copyIcon = '<svg viewBox="0 0 24 24" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>';
        const successIcon = '<svg viewBox="0 0 24 24" stroke="#a6e22e" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>';
        const linkIcon = '<svg viewBox="0 0 24 24" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round" style="width:14px;height:14px;"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"></path><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"></path></svg>';

        copyBtn.innerHTML = copyIcon;
        copyBtn.addEventListener('click', async () => {
          try {
            await navigator.clipboard.writeText(code);
            copyBtn.innerHTML = successIcon;
            setTimeout(() => { copyBtn.innerHTML = copyIcon; }, 2000);
          } catch (err) {
            console.error("Fehler beim Kopieren:", err);
          }
        });

        // Header-Logik
        if (titleText) {
          const header = document.createElement('div');
          header.className = 'shiki-header';

          // Titel-Element (als Link, wenn data-url existiert)
          const titleEl = document.createElement(titleUrl ? 'a' : 'span');
          titleEl.className = 'shiki-title';
          
          if (titleUrl) {
            titleEl.href = titleUrl;
            titleEl.target = '_blank';
            titleEl.innerHTML = `${linkIcon} ${titleText}`;
          } else {
            titleEl.textContent = titleText;
          }

          header.appendChild(titleEl);
          header.appendChild(copyBtn);
          wrapper.appendChild(header);
        } else {
          // Fallback, wenn kein Titel vergeben wurde
          wrapper.classList.add('no-header');
          wrapper.appendChild(copyBtn);
        }

        // Den eigentlichen Shiki HTML-Code einfügen
        wrapper.insertAdjacentHTML('beforeend', html);
        block.parentElement.replaceWith(wrapper);

      } catch (e) {
        console.warn(`Shiki konnte Sprache '${lang}' nicht rendern.`, e);
      }
    });

    console.log("Fertig! Highlighting erfolgreich geladen.");

    // Hover-Logik für Text-zu-Code Verlinkung
    const hoverTriggers = document.querySelectorAll('.code-hover');
    hoverTriggers.forEach(trigger => {
      trigger.addEventListener('mouseenter', () => {
        const targetLine = parseInt(trigger.getAttribute('data-line'), 10);
        const targetBlock = parseInt(trigger.getAttribute('data-block') || '1', 10);
        if (!targetLine) return;
        
        const shikiBlocks = document.querySelectorAll('pre.shiki');
        const activeBlock = shikiBlocks[targetBlock - 1]; 
        
        if (activeBlock) {
          const lines = activeBlock.querySelectorAll('.line');
          const lineEl = lines[targetLine - 1]; 
          if (lineEl) lineEl.classList.add('is-hovered'); 
        }
      });
      
      trigger.addEventListener('mouseleave', () => {
        document.querySelectorAll('pre.shiki .line.is-hovered').forEach(el => {
          el.classList.remove('is-hovered');
        });
      });
    });

  } catch (err) {
    console.error("Fehler beim Ausführen von Shiki:", err);
  }
})();