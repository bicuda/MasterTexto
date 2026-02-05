export function timeAgo(date: Date): string {
    const seconds = Math.floor((new Date().getTime() - date.getTime()) / 1000);

    let interval = seconds / 31536000;
    if (interval > 1) return Math.floor(interval) + "a atrás";

    interval = seconds / 2592000;
    if (interval > 1) return Math.floor(interval) + "m atrás";

    interval = seconds / 86400;
    if (interval > 1) return Math.floor(interval) + "d atrás";

    interval = seconds / 3600;
    if (interval > 1) return Math.floor(interval) + "h atrás";

    interval = seconds / 60;
    if (interval > 1) return Math.floor(interval) + "min atrás";

    return Math.floor(seconds) + "s atrás";
}
