/** @type {import('tailwindcss').Config} */
export default {
    content: [
        "./index.html",
        "./src/**/*.{js,ts,jsx,tsx}",
    ],
    theme: {
        extend: {
            fontFamily: {
                sans: ['Inter', 'sans-serif'],
            },
            colors: {
                dark: {
                    900: '#121212',
                    800: '#1E1E1E',
                    700: '#2C2C2C',
                },
                brand: {
                    500: '#3B82F6', // A nice primary blue
                    600: '#2563EB',
                }
            }
        },
    },
    plugins: [],
}
