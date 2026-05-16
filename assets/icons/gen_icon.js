const sharp = require('sharp');
const fs = require('fs');

const svgForeground = `<svg width="140" height="140" viewBox="0 0 140 140" xmlns="http://www.w3.org/2000/svg">
  <g>
    <circle cx="70" cy="70" r="48" stroke="#51CF66" stroke-width="5" fill="none" stroke-linecap="round" opacity="0.85"/>
    <rect x="48" y="50" width="18" height="34" rx="3" fill="#FFFFFF" opacity="0.95"/>
    <line x1="51" y1="60" x2="63" y2="60" stroke="#FF6B6B" stroke-width="2.5" opacity="0.9" stroke-linecap="round"/>
    <line x1="51" y1="72" x2="63" y2="72" stroke="#FF6B6B" stroke-width="2.5" opacity="0.9" stroke-linecap="round"/>
    <g transform="rotate(-10 74 67)"><rect x="70" y="52" width="9" height="30" rx="2" fill="#FFFFFF" opacity="0.9"/></g>
    <g transform="rotate(-8 86 67)"><rect x="82" y="52" width="9" height="30" rx="2" fill="#FFFFFF" opacity="0.85"/></g>
  </g>
</svg>`;

sharp(Buffer.from(svgForeground)).resize(1024, 1024).png().toFile('ic_launch_foreground.png')
  .then(() => console.log('OK foreground'))
  .catch(e => console.log(e.message));
