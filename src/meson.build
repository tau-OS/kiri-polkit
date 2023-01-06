agent_files = files(
    'AuthPrompt.vala',
)

agent_deps = [
    dependency('libhelium-1', fallback: [ 'libhelium', 'helium_dep' ]),
    dependency('libbismuth-1', fallback: [ 'libbismuth', 'bismuth_dep' ]),
    m_dep
]

executable(
    meson.project_name(),
    agent_files,
    conf_file,
    dependencies: agent_deps,
    install: true,
)