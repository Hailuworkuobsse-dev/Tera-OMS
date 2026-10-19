const tokens = require('./src/tokens.json');
/** @type {import('tailwindcss').Config} */
module.exports = {
  theme: {
    extend: {
      colors: tokens.color,
      fontFamily: { sans: tokens.font.sans, mono: tokens.font.mono },
      borderRadius: tokens.radius,
    },
  },
};
