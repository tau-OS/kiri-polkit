agent_files = files(
    'Agent.vala',
    'Utils.vala',
    'Widget/AuthPrompt.vala',
    'Interfaces.vala',
)

agent_deps = [
    dependency('libhelium-1', fallback: [ 'libhelium', 'helium_dep' ]),
    dependency('libbismuth-1', fallback: [ 'libbismuth', 'bismuth_dep' ]),
    m_dep,
    dependency('polkit-gobject-1'),
    dependency('gobject-2.0'),
    dependency('polkit-agent-1'),
    meson.get_compiler('vala').find_library('posix'),

]

executable(
    meson.project_name(),
    agent_files,
    conf_file,
    c_args: [
        '-DPOLKIT_AGENT_I_KNOW_API_IS_SUBJECT_TO_CHANGE',
    ],
    dependencies: agent_deps,
    install: true,
)