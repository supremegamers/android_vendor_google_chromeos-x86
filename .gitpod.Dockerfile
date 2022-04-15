FROM gitpod/workspace-full:latest

RUN curl --proto '=https' --tlsv1.2 -sSfL "https://git.io/Jc9bH" | bash -s selfinstall

RUN sudo install-packages p7zip-full squashfs-tools