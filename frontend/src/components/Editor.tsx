import { useEffect, useState } from 'react';
import { io, Socket } from 'socket.io-client';
import { useParams } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { Cloud, RotateCw } from 'lucide-react';
import { cn } from '../lib/utils';
import { useEditor, EditorContent } from '@tiptap/react';
import StarterKit from '@tiptap/starter-kit';
import Link from '@tiptap/extension-link';
import { timeAgo } from '../lib/time';

// Connect to backend (proxy handles /socket.io path)
const socket: Socket = io('/', {
    transports: ['websocket', 'polling'],
    autoConnect: false,
});

// Helper for local storage
const STORAGE_KEY_VISITED = 'mastertexto_visited_links';
const STORAGE_KEY_SAFETY = 'mastertexto_safety_mode';

export const Editor = () => {
    const { roomId } = useParams<{ roomId: string }>();
    const [isConnected, setIsConnected] = useState(false);
    const [isSaving, setIsSaving] = useState(false);
    const [lastUpdated, setLastUpdated] = useState<Date>(new Date());
    const [timeAgoStr, setTimeAgoStr] = useState('agora');

    // Safety Mode State
    const [safetyMode, setSafetyMode] = useState(false);
    const [visitedLinks, setVisitedLinks] = useState<Set<string>>(new Set());
    const [modalLink, setModalLink] = useState<string | null>(null);

    // Load Safety Settings on Mount
    useEffect(() => {
        const savedSafety = localStorage.getItem(STORAGE_KEY_SAFETY) === 'true';
        setSafetyMode(savedSafety);

        const savedLinks = localStorage.getItem(STORAGE_KEY_VISITED);
        if (savedLinks) {
            try {
                setVisitedLinks(new Set(JSON.parse(savedLinks)));
            } catch (e) {
                console.error("Failed to parse visited links", e);
            }
        }
    }, []);

    // Toggle Safety Mode
    const toggleSafetyMode = () => {
        const newState = !safetyMode;
        setSafetyMode(newState);
        localStorage.setItem(STORAGE_KEY_SAFETY, String(newState));
    };

    // Handle Link Opening
    const openLink = (url: string) => {
        window.open(url, '_blank', 'noopener,noreferrer');
        // Add to visited if not present
        if (!visitedLinks.has(url)) {
            const newSet = new Set(visitedLinks);
            newSet.add(url);
            setVisitedLinks(newSet);
            localStorage.setItem(STORAGE_KEY_VISITED, JSON.stringify(Array.from(newSet)));
        }
        setModalLink(null);
    };

    const handleLinkClick = (url: string) => {
        if (!safetyMode) {
            openLink(url);
            return;
        }

        if (visitedLinks.has(url)) {
            // Already visited -> Show Warning
            setModalLink(url);
        } else {
            // First time -> Open and Mark as visited
            openLink(url);
        }
    };

    // Update "time ago" string every 5 seconds
    useEffect(() => {
        const interval = setInterval(() => {
            setTimeAgoStr(timeAgo(lastUpdated));
        }, 5000);
        return () => clearInterval(interval);
    }, [lastUpdated]);

    // Initial time ago set
    useEffect(() => {
        setTimeAgoStr(timeAgo(lastUpdated));
    }, [lastUpdated]);

    // Initialize Tiptap Editor
    const editor = useEditor({
        extensions: [
            extensions: [
                Link.configure({
                    openOnClick: false, // Handle manually
                    autolink: true,
                    linkOnPaste: true,
                    defaultProtocol: 'https',
                    HTMLAttributes: {
                        class: 'cursor-pointer',
                        target: '_blank',
                        rel: 'noopener noreferrer'
                    }
                }),
                StarterKit,
            ],
            editorProps: {
                attributes: {
                    class: 'w-full h-full bg-transparent focus:outline-none text-lg md:text-xl leading-relaxed text-zinc-100 placeholder:text-zinc-600 font-sans prose prose-invert max-w-none',
                },
                handleClickOn: (view, pos, node, nodePos, event, direct) => {
                    if (node.type.name === 'link') {
                        const href = node.attrs.href;
                        if (href) {
                            handleLinkClick(href);
                            return true; // Stop propagation
                        }
                    }
                    return false;
                },
                handlePaste: (view, event) => {
                    const text = event.clipboardData?.getData('text/plain');
                    // Check if pasted text is a URL
                    if (text && /^(https?:\/\/[^\s]+)$/.test(text.trim())) {
                        const url = text.trim();
                        const { state, dispatch } = view;
                        const { tr, selection, schema } = state;

                        // Create a link mark
                        const linkMark = schema.marks.link.create({
                            href: url,
                            target: '_blank',
                            rel: 'noopener noreferrer'
                        });

                        // 1. Replace the entire current selection with the linked text
                        // 2. Split the block at the end of the insertion to create a new line (Enter)
                        const transaction = tr
                            .replaceWith(selection.from, selection.to, schema.text(url, [linkMark]))
                            .split(selection.from + url.length);

                        dispatch(transaction);

                        // Force focus and scroll
                        requestAnimationFrame(() => {
                            view.focus();
                            if (view.dom) {
                                view.dom.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
                            }
                        });

                        return true; // Prevent default behavior
                    }
                    return false; // Default behavior
                }
            },
            onUpdate: ({ editor }) => {
                const html = editor.getHTML();
                socket.emit('text_change', { roomId, content: html });
                setIsSaving(true);
                setLastUpdated(new Date());
                setTimeout(() => setIsSaving(false), 800);
            },
    });

    useEffect(() => {
        if (!roomId || !editor) return;

        socket.connect();
        socket.emit('join_room', roomId);
        setIsConnected(true);

        socket.on('connect', () => setIsConnected(true));
        socket.on('disconnect', () => setIsConnected(false));

        socket.on('load_content', (data: string) => {
            if (editor.getHTML() !== data) {
                editor.commands.setContent(data, { emitUpdate: false });
                setLastUpdated(new Date());
            }
        });

        socket.on('text_update', (data: string) => {
            if (editor.getHTML() !== data) {
                const { from, to } = editor.state.selection;
                editor.commands.setContent(data, { emitUpdate: false });
                setLastUpdated(new Date());
                try {
                    editor.commands.setTextSelection({ from, to });
                } catch (e) {
                    // Ignore index out of range errors
                }
            }
        });

        return () => {
            socket.off('connect');
            socket.off('disconnect');
            socket.off('load_content');
            socket.off('text_update');
            socket.disconnect();
        };
    }, [roomId, editor]);

    const handleRefresh = () => {
        window.location.reload();
    };

    return (
        <div className="flex flex-col h-[100dvh] max-w-5xl mx-auto p-4 md:p-8">
            {/* Header */}
            <motion.header
                initial={{ opacity: 0, y: -20 }}
                animate={{ opacity: 1, y: 0 }}
                className="flex justify-between items-center mb-6"
            >
                <div>
                    <h1 className="text-2xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-blue-400 to-purple-500">
                        MasterTexto
                    </h1>
                    <p className="text-zinc-400 text-sm">Sala: <span className="text-zinc-200 font-mono bg-zinc-800 px-2 py-0.5 rounded">{roomId}</span></p>
                </div>

                <div className="flex items-center gap-3">
                    <div className="flex flex-col items-end mr-2">
                        <span className="text-xs text-zinc-500">Última atualização</span>
                        <span className="text-xs text-zinc-300 font-mono">{timeAgoStr}</span>
                    </div>

                    {/* Safety Toggle */}
                    <button
                        onClick={toggleSafetyMode}
                        className={cn(
                            "flex items-center gap-2 px-3 py-1.5 rounded-full text-xs font-medium transition-colors border",
                            safetyMode
                                ? "bg-blue-500/10 text-blue-400 border-blue-500/20 hover:bg-blue-500/20"
                                : "bg-zinc-800 text-zinc-400 border-zinc-700 hover:bg-zinc-700"
                        )}
                        title={safetyMode ? "Modo Seguro Ativado (Verifica links repetidos)" : "Modo Seguro Desativado"}
                    >
                        <div className={cn("w-2 h-2 rounded-full", safetyMode ? "bg-blue-500 animate-pulse" : "bg-zinc-500")} />
                        {safetyMode ? "Seguro" : "Padrão"}
                    </button>

                    <button
                        onClick={handleRefresh}
                        className="p-2 rounded-full bg-zinc-800 hover:bg-zinc-700 text-zinc-400 transition-colors"
                        title="Recarregar Página"
                    >
                        <RotateCw size={16} />
                    </button>

                    <div className={cn(
                        "flex items-center gap-2 px-3 py-1.5 rounded-full text-xs font-medium transition-colors",
                        isConnected ? "bg-green-500/10 text-green-400" : "bg-red-500/10 text-red-400"
                    )}>
                        <div className={cn("w-2 h-2 rounded-full", isConnected ? "bg-green-500" : "bg-red-500")} />
                        {isConnected ? "Online" : "Conectando..."}
                    </div>

                    <AnimatePresence>
                        {isSaving && (
                            <motion.div
                                initial={{ opacity: 0, scale: 0.8 }}
                                animate={{ opacity: 1, scale: 1 }}
                                exit={{ opacity: 0, scale: 0.8 }}
                                className="flex items-center gap-1.5 text-xs text-blue-400"
                            >
                                <Cloud size={14} />
                                <span>Salvando...</span>
                            </motion.div>
                        )}
                    </AnimatePresence>
                </div>
            </motion.header>

            {/* Editor Area */}
            <motion.div
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ delay: 0.1 }}
                className="flex-1 relative group bg-zinc-900/50 backdrop-blur-sm border border-zinc-800 rounded-2xl shadow-xl overflow-hidden"
            >
                <div className="absolute inset-0 bg-gradient-to-br from-blue-500/10 via-purple-500/5 to-pink-500/10 rounded-2xl blur-2xl opacity-60 pointer-events-none" />

                {/* Tiptap Editor Content */}
                <div className="h-full w-full p-6 md:p-8 overflow-y-auto custom-scrollbar">
                    <EditorContent editor={editor} className="h-full outline-none" />
                </div>
            </motion.div>

            {/* Footer */}
            <motion.footer
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ delay: 0.2 }}
                className="mt-6 text-center text-zinc-600 text-sm"
            >
                <p>Compartilhe este link para colaborar em tempo real.</p>
                <p className="text-xs mt-1 text-zinc-700">Digite uma URL (ex: google.com) para criar um link.</p>
            </motion.footer>
        </div>
    );
};
